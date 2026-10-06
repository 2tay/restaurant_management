# Phone push for the owner

The owner gets a push on their Android phone for what matters most when they are not in the
restaurant. Everything else stays in the bell.

| Alert | When the push goes | Example |
|---|---|---|
| **Rupture de stock** | at once, one per product | *Rupture de stock : Poulet* — *Brasserie du Sablon — Il ne reste plus de poulet.* |
| **Stock faible** | grouped: two minutes after the first, every stock faible of that store as one push | *Stock faible : 5 produits* — *Brasserie du Sablon — Tomates, Oignons, Lait et 2 autres.* |
| **Jours chargés** | at once, once per busy period | *Jours chargés demain* — *… 4 produits sont sous le minimum de forte affluence.* |

- **Owner only.** A manager's phone, or a tablet a manager is signed in on, gets nothing.
- **Android only** for now. No Google Play account is needed: the app is installed from an APK.
- **The in-app switches still decide.** *Paramètres → Notifications → Stock faible / Jours
  chargés* off means no notification, so no push either.
- **Tapping** a stock push opens the store's *Alertes*; a jours chargés push opens the
  notifications.
- **A push goes when the alert reaches the server**, not when it happens: an offline tablet's
  alerts are pushed when it reconnects. Nothing older than a day is pushed.

---

## How it works

```
tablet ──sync──▶ notifications (server) ──trigger──▶ push_queue
                                                         │  every minute, while not empty
                                                         ▼
                           cron ──▶ Edge Function send-pushes ──▶ claim_pushes()
                                                         │  grouped, worded, + owner phones
                                                         ▼
                                    Google sign-in ──▶ Firebase Cloud Messaging ──▶ phone
```

1. **The phone registers itself** (`lib/services/push_service.dart`). While the **owner** is
   the one signed in on an account device, the app asks for permission and sends the phone's
   Firebase token to `register_push_device`. Anyone else signed in, or nobody, and it calls
   `unregister_push_device`. Signing the account out of the device unregisters it and drops
   the token.
2. **The server queues** (`supabase/migrations/20261006000200_owner_push.sql`). A trigger on
   `notifications` puts each rupture, stock faible and jours chargés into `push_queue` the
   first time it reaches the server. A notification filed on two tablets has one id, so it is
   queued once.
3. **The server groups** (`claim_pushes`). A rupture or a jours chargés is due at once. A
   stock faible waits until the oldest one of its store is two minutes old; then all of them
   go as one push. Each push comes with the tokens of the owner's phones.
4. **The Edge Function sends** (`supabase/functions/send-pushes/index.ts`). The cron job calls
   it every minute while the queue is not empty. It signs in to Google with the Firebase
   service account, sends through FCM, and forgets a phone Firebase says is gone.

A push is claimed before it is sent, so it is **sent at most once**. A failed send is logged,
not retried: the bell still has the notification.

---

## Setting it up on a Supabase project (once)

Already done: the Firebase project, `android/app/google-services.json`, and the
`FIREBASE_SERVICE_ACCOUNT` secret.

**1. Apply the migrations** — from the project folder, with the CLI linked to the project:

```
supabase db push
```

**2. Choose a shared secret** for the cron job — any long random text, e.g. from a password
generator. It proves to the function that the call comes from your database.

**3. Give it to the function** — Supabase dashboard → *Edge Functions → Secrets* → add
`PUSH_CRON_SECRET` with that text.

**4. Give it, and the project's address, to the database** — Supabase dashboard → *SQL
Editor*, run (with your own values):

```sql
select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
select vault.create_secret('<the same random text>', 'push_cron_secret');
```

`<project-ref>` is in *Project Settings → General*.

**5. Deploy the function:**

```
supabase functions deploy send-pushes
```

(`supabase/config.toml` turns JWT verification off for it: the secret header is its check.)

**6. Install the app on the owner's phone and sign in as the owner.** Allow notifications when
asked. In *Table Editor → push_devices* a row appears for the phone.

### Checking it

- Record a stock-out that takes a product to zero on a tablet → within about a minute of the
  tablet syncing, the phone shows *Rupture de stock*.
- *Edge Functions → send-pushes → Logs* shows each call: `{"sent": 1, ...}`.
- *Database → Cron Jobs* shows `send-owner-pushes` running every minute.
- `select * from push_queue order by queued_at desc;` shows what was queued and when it was
  claimed.

---

## Secrets — never in git

| Secret | Where it lives |
|---|---|
| Firebase service account (`FIREBASE_SERVICE_ACCOUNT`) | Supabase *Edge Functions → Secrets* only |
| `PUSH_CRON_SECRET` | Supabase *Edge Functions → Secrets*, and the Vault as `push_cron_secret` |
| `google-services.json` | **In git** — not a secret: it names the project, it cannot send |

`.gitignore` refuses `supabase/functions/.env` and any `*service-account*.json` /
`*firebase-adminsdk*.json`. To run the function locally (`supabase functions serve
send-pushes --env-file …`), keep the env file outside the project.

Before real users: generate a new service account key in Firebase, put it in the secret, and
delete the old key in *Google Cloud → IAM → Service accounts*.

---

## Files

| What | Where |
|---|---|
| Phone side: permission, token, register / unregister, taps | `lib/services/push_service.dart` |
| Started on Android | `lib/main.dart` |
| Unregister on account sign-out | `lib/data/device_access.dart` (`signOutAccount`) |
| Server: tables, trigger, grouping, cron | `supabase/migrations/20261006000200_owner_push.sql` |
| Sender | `supabase/functions/send-pushes/index.ts` |
| Tests | `test/push_controller_test.dart`, `supabase/tests/database/push.test.sql` |
| Android | `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `AndroidManifest.xml` |

## Not done yet

- iPhone (needs an Apple Developer account and an APNs key in Firebase).
- Quiet hours, and push switches separate from the in-app ones.
- A custom notification icon: Android shows the app icon.
