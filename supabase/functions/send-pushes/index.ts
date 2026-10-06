// Sends the owner's phone pushes (PUSH_NOTIFICATIONS.md).
//
// Called every minute by the `send-owner-pushes` cron job while the queue
// holds something (migration 20261006000200_owner_push.sql). Each call:
//
// 1. claims what is due with `claim_pushes` — already grouped, worded, and
//    with the owner's phones to send it to;
// 2. signs in to Google with the Firebase service account (the
//    FIREBASE_SERVICE_ACCOUNT secret) and sends each push through Firebase
//    Cloud Messaging;
// 3. forgets a phone Firebase says is gone (`forget_push_token`).
//
// A push is claimed before it is sent, so it is sent at most once: a failed
// send is logged, not retried. A push is a courtesy on top of the bell,
// which still holds the notification.
//
// The cron job proves itself with the `x-push-secret` header, the same value
// as the PUSH_CRON_SECRET secret. Deployed with JWT verification off
// (`supabase/config.toml`), so that header is the only check.

import { createClient } from "jsr:@supabase/supabase-js@2";

type Push = {
  store_id: string;
  kind: string;
  title: string;
  body: string;
  tokens: string[];
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

const MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

Deno.serve(async (request) => {
  const secret = Deno.env.get("PUSH_CRON_SECRET");
  if (!secret || request.headers.get("x-push-secret") !== secret) {
    return json({ error: "forbidden" }, 403);
  }

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) return json({ error: "FIREBASE_SERVICE_ACCOUNT is not set" }, 500);
  let account: ServiceAccount;
  try {
    account = JSON.parse(raw);
  } catch {
    return json({ error: "FIREBASE_SERVICE_ACCOUNT is not JSON" }, 500);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase.rpc("claim_pushes");
  if (error) return json({ error: error.message }, 500);
  const pushes = (data ?? []) as Push[];
  if (pushes.length === 0) return json({ sent: 0, failed: 0, forgotten: 0 });

  let accessToken: string;
  try {
    accessToken = await googleAccessToken(account);
  } catch (e) {
    // The pushes claimed above are lost: the bell still has them.
    console.error(e);
    return json({ error: String(e), lost: pushes.length }, 500);
  }

  let sent = 0;
  let failed = 0;
  let forgotten = 0;
  for (const push of pushes) {
    for (const token of push.tokens) {
      const outcome = await send(account.project_id, accessToken, token, push);
      if (outcome === "sent") {
        sent++;
      } else {
        failed++;
        if (outcome === "gone") {
          await supabase.rpc("forget_push_token", { p_token: token });
          forgotten++;
        }
      }
    }
  }
  return json({ sent, failed, forgotten });
});

/// One push to one phone.
async function send(
  projectId: string,
  accessToken: string,
  token: string,
  push: Push,
): Promise<"sent" | "gone" | "failed"> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: push.title, body: push.body },
          // Read by the app when the push is tapped: which store, which page.
          data: { store_id: push.store_id, kind: push.kind },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (response.ok) return "sent";

  const text = await response.text();
  console.error(`FCM ${response.status} for ${push.kind}: ${text}`);
  // The phone uninstalled the app, or the token was never valid. Not a
  // malformed message on our side: that would be a 400 about something else.
  if (
    response.status === 404 ||
    text.includes("UNREGISTERED") ||
    (response.status === 400 && text.includes("registration token"))
  ) {
    return "gone";
  }
  return "failed";
}

// ---------------------------------------------------------------------------
// Google sign-in with the service account (OAuth 2.0, JWT bearer grant)
// ---------------------------------------------------------------------------

let cached: { token: string; expiresAt: number } | null = null;

/// An access token for Firebase Cloud Messaging, kept until five minutes
/// before it expires.
async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expiresAt - 300 > now) return cached.token;

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: MESSAGING_SCOPE,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const response = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(new Uint8Array(signature))}`,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google sign-in failed: ${await response.text()}`);
  }
  const answer = await response.json();
  cached = {
    token: answer.access_token,
    expiresAt: now + (answer.expires_in ?? 3600),
  };
  return cached.token;
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
