# Manual tests: several tablets and sync

This file is the test script to run **before we deliver the app to the client**. It simulates a
real restaurant: two or more tablets, the same account, people working at the same time, the
Wi-Fi going off and coming back.

Do the tests **one by one, in order**. Each test says:

- **Goal**: what we want to prove.
- **Before**: what must be ready.
- **Steps**: what to do, on which tablet, in which order.
- **Expected**: what you must see at the end, **on every tablet**.
- **Result**: tick **OK**, or tick **KO** and write what you saw.

The app is in French. Buttons and messages are written here **exactly as they appear on the
screen**, in « French quotes ».

---

## 0. Before you start

### 0.1 What you need

- [ ] **Two tablets** (called **A** and **B** in this file). A third device (**C**, for example
      a Windows PC) is needed only for part 11.
- [ ] An **Android phone** for the owner, only for the push tests (part 9).
- [ ] **The same app version** on every device.
- [ ] **Automatic date and time** turned on, on every device. Some rules compare hours.
- [ ] Two **e-mail addresses** you can open (one for the owner, one for a manager).
- [ ] The cloud "dev" server is ready: the migrations in `supabase/migrations/` are applied
      (`supabase db push`), and `config/dev.json` holds its URL and publishable key.

### 0.2 How to start the app

From the project folder:

```
flutter run -d <device> --dart-define-from-file=config/dev.json
```

`<device>` is the device id from `flutter devices` (for example `windows`, or the id of the
Android tablet). For a tablet without a cable, build once and install the APK:

```
flutter build apk --dart-define-from-file=config/dev.json
```

If the welcome page says « Aucun serveur n'est configuré dans cette version », the app was
started **without** `config/dev.json`. Stop and start again with it.

### 0.3 Actions used in every test

| Action | How to do it |
|---|---|
| **Cut the network** | Turn on airplane mode (or turn off Wi-Fi) on the tablet named. |
| **Bring the network back** | Turn off airplane mode (or turn on Wi-Fi). |
| **Sync** | « Paramètres » → « Synchronisation » → « Synchroniser maintenant ». |
| **Full round** | Bring the network back on **all** tablets, then **Sync A, then B, then A again**. If a result is still different, Sync B once more. |
| **Open the sync page** | « Paramètres » → « Synchronisation » (title « État de la synchronisation »). |
| **Open the notifications** | Tap the **bell** at the top of the screen. |

> **The order of sync matters.** When a rule says "the last one wins" or "the first one
> wins", it means the order in which the tablets **send** to the server. Always follow the
> order written in the test.

### 0.4 Check this at the end of **every** test

1. A and B show **exactly the same thing** (names, quantities, prices, statuses, hours,
   amounts).
2. The sync page says « À jour » on both tablets, with « Aucune modification en attente ».
3. Nothing was lost (except when the test says it should be).
4. The list « À vérifier » on the sync page is empty, **unless** the test expects a message
   there.

### 0.5 When a test fails (KO)

Write down:

- the **test code** (for example `ST2`);
- the **tablet** where it was wrong;
- what you **expected** and what you **saw**;
- the **time**;
- a **screenshot** of the screen **and** of the sync page, on both tablets.

Then continue with the next test, unless the KO blocks it.

---

## 1. Accounts and devices

### AC1 — The owner creates the restaurant on tablet A

**Goal:** a new owner can create an account and a restaurant.
**Before:** tablet A has a fresh install (the welcome page « Bienvenue » opens).

**Steps:**
1. **A:** tap « Créer un compte ».
2. Enter the owner's e-mail and a password of **8 characters or more**, twice. Tap
   « Créer le compte ».
3. If the app says « Confirmez votre adresse e-mail avec le lien reçu, puis connectez-vous. »,
   open the e-mail, tap the link, come back and tap « Se connecter ».
4. On « Votre restaurant », stay on the « Créer » tab. Fill in « Nom du restaurant »
   (for example `Test Brasserie`), « Ville », « Téléphone », « Prénom », « Nom », « Votre PIN ».
5. Tap « Créer le restaurant ».

**Expected:**
- The app opens on the PIN login, then on the dashboard of the new restaurant.
- « Paramètres » → « Compte »: the role is « Propriétaire ».
- The sync page says « À jour ».

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC2 — Wrong password and short password

**Goal:** account errors are clear.

**Steps:**
1. On a device on the welcome page, try « Se connecter » with the owner's e-mail and a
   **wrong** password.
2. Try « Créer un compte » with a password of **5 characters**.
3. Try « Créer un compte » with the **owner's e-mail again**.

**Expected:**
1. « Adresse e-mail ou mot de passe incorrect. »
2. « Le mot de passe doit faire au moins 8 caractères. »
3. « Un compte existe déjà avec cette adresse. »

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC3 — A manager joins with a code on tablet B

**Goal:** a second person and a second tablet join the same restaurant.
**Before:** AC1 done. Tablet B has a fresh install.

**Steps:**
1. **A (owner):** « Paramètres » → « Compte » → « Inviter un gérant ». Write down the
   8-character code.
2. **B:** « Créer un compte » with the **manager's** e-mail. Confirm the e-mail if asked.
3. **B:** on « Votre restaurant », open the « Rejoindre » tab, type the code in
   « Code d'invitation », tap « Rejoindre le restaurant ».

**Expected:**
- B shows « Presque prêt » and « Téléchargement des données… N éléments », then opens.
- B shows the same restaurant, the same store and the same data as A.
- On B, « Paramètres » → « Compte »: the role is « Gérant ».

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC4 — A code works only once

**Steps:**
1. Use the **same code** from AC3 again, with a third e-mail, on any device.
2. Type a made-up code, for example `ABCD1234`.

**Expected:** both times, « Code invalide ou expiré. »

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC5 — The list of devices

**Steps:**
1. **A:** « Paramètres » → « Compte » → « Appareils ».

**Expected:**
- A and B are both in the list, with their tablet number: A is « T1 · … », B is « T2 · … ».
- A is marked « Cet appareil ».
- Each line shows « Vu le … » with a recent date.
- A new order made on A is numbered `CMD-2026-T1-…`, one made on B `CMD-2026-T2-…`.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC6 — The demo never goes to the server

**Goal:** demo data stays on the device.

**Steps:**
1. On a **third** device (or after a reinstall), on the welcome page, tap « Essayer la démo ».
2. Make a change (for example a stock out).
3. Open the sync page.
4. On A, Sync.

**Expected:**
- The demo sync page says « Démonstration — rien n'est envoyé ».
- A and B **never** show the demo stores (Brasserie du Sablon, Taverne Saint-Gilles…).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC7 — A demo device connects to the account

**Goal:** turning a demo device into a real one removes the demo data.

**Steps:**
1. On the demo device of AC6: « Paramètres » → « Compte » → « Connecter un compte ».
2. Sign in with the **manager's** account (or a new invited manager).

**Expected:**
- The app warns « Les données de démonstration de cet appareil seront effacées. »
- After sign-in, the device shows only the real restaurant. No demo store is left.
- A and B still show no demo data.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC8 — A device with its own data joins an account that already has data

**Goal:** local data is saved to a backup file before it is replaced.
**Before:** a device in demo mode where you created your **own** store (not a demo store) with
a few products.

**Steps:**
1. On that device, connect to the restaurant account (as in AC7).

**Expected:**
- The page « Données déjà sur cet appareil » appears and says that the account already contains
  data and that the data of this device will be saved to a backup file.
- Tap « Sauvegarder et continuer ».
- A message « Sauvegarde enregistrée : … » shows the path of the file. The file exists.
- The device then shows the account's data only.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC9 — The owner removes a device

**Steps:**
1. **A (owner):** « Paramètres » → « Compte » → « Appareils » → on the device of AC7/AC8,
   tap « Retirer » and confirm.
2. On that removed device, make a change and Sync.

**Expected:**
- The removed device says « Le propriétaire a retiré cet appareil du restaurant. Les
  modifications restent sur l'appareil. »
- The change does **not** appear on A or B.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AC10 — Sign out wipes the tablet

**Goal:** a lost or handed-over tablet can be cleaned. (SYNC_PLAN 11.2, point 9)

**Steps:**
1. **B:** cut the network. Make one change (for example a stock out).
2. **B:** « Paramètres » → « Compte » → « Se déconnecter du compte ».
3. Read the warning, then **cancel**.
4. Bring the network back on B. Sync B. Do step 2 again and **confirm**.

**Expected:**
- Step 3: the warning says « Toutes les données de cet appareil seront effacées… » and
  « 1 modification n'a pas encore été envoyée et sera perdue. »
- Step 4: B goes back to the welcome page « Bienvenue ». Nothing of the restaurant is left on B.
- A still has everything, including the change B sent before signing out.
- **Then:** sign B in again with the manager account. B downloads everything again.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 2. Basic sync, online

All tests in this part: **both tablets online**.

### BS1 — Created on A, seen on B

**Goal:** new data goes from one tablet to the other. (SYNC_PLAN 11.2, points 1–2)

**Steps:**
1. **A:** « Catégories et unités »: create a category `Test Boissons` and a unit `Bouteille`.
2. **A:** « Fournisseurs »: create a supplier `Fournisseur Test`.
3. **A:** « Produits »: create 3 products, for example `Eau test`, `Cola test`, `Farine test`,
   with the category, the unit, the supplier, a price and a minimum stock.
4. **Do not press anything on B.** Wait 10 seconds and watch B.

**Expected:**
- Within a few seconds, B shows the category, the unit, the supplier and the 3 products,
  **without** pressing « Synchroniser maintenant » (live update).
- If B does not update by itself within one minute: press Sync on B and write this down as a
  KO (the data must still arrive).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### BS2 — Edited on B, seen on A

**Steps:**
1. **B:** open `Cola test`. Change its name to `Cola test 33cl` and its minimum stock.
2. Watch A.

**Expected:** A shows the new name and minimum within a few seconds.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### BS3 — Deleted on A, gone on B

**Steps:**
1. **A:** delete the product `Farine test`.
2. Watch B.

**Expected:** `Farine test` disappears from B too (list, search, alerts).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### BS4 — Kill the app and reopen

**Steps:**
1. On A and B, close the app completely (swipe it away), then open it again.

**Expected:** all data of BS1–BS3 is still there on both, and the sync page says « À jour ».

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 3. Working offline

### OF1 — The offline banner and the waiting count

**Goal:** the tablet works without the internet and says so honestly.

**Steps:**
1. **B:** cut the network.
2. **B:** do 3 changes: one stock out of `Eau test`, one new product `Sel test`, one price
   change on `Cola test 33cl`.
3. Look at the banner at the top and at the sync page.

**Expected:**
- The banner appears and shows « Serveur injoignable » with « 3 modifications en attente »
  (the number can be a bit higher if a change touches several rows; it must **not** be 0).
- The sync page says « Hors ligne — nouvel essai automatique ».
- B keeps working normally. Nothing is blocked.
- A does **not** see the 3 changes yet.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OF2 — The network comes back

**Steps:**
1. **B:** bring the network back. **Do not press anything.** Wait one minute.

**Expected:**
- B sends by itself. The banner disappears, « Aucune modification en attente ».
- A shows the 3 changes.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OF3 — Close the app while offline

**Goal:** waiting changes survive a closed app.

**Steps:**
1. **B:** cut the network. Make 2 changes.
2. **B:** close the app completely. Reopen it. Check the banner still shows the waiting
   changes.
3. Bring the network back. Wait.

**Expected:** after reopening, the 2 changes are still on B and still waiting. When the
network is back, they reach A.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OF4 — A long time offline

**Steps:**
1. **B:** cut the network for **at least one hour** (or overnight) while A keeps working
   (A: 5 stock outs, 1 new product, 1 price change).
2. **B:** during that time, do 5 stock outs too.
3. Full round.

**Expected:** both tablets show the same stock for every product, and all 10 stock outs are in
« Mouvements de stock » on both.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 4. Stock

> Rule to remember: the stock quantity is **never copied** from one tablet to another. Each
> tablet **recomputes** it from the list of movements. So two tablets always end with the same
> number, and no stock out is lost.

### ST1 — Both tablets take stock out of the same product, offline

**Goal:** no stock out is lost. (SYNC_PLAN 11.2, point 3)
**Before:** `Eau test` has **50** in stock on both tablets.

**Steps:**
1. Cut the network on A and B.
2. **A:** « Sortie de stock » of `Eau test`: **5**. « Enregistrer la sortie ».
3. **B:** « Sortie de stock » of `Eau test`: **3**.
4. Full round.

**Expected on A and B:** `Eau test` = **42** (50 − 5 − 3). Both stock outs are in the
movements list.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### ST2 — A stock count on A while B takes stock out (out before the count)

**Goal:** a count is the real number on the shelf at that time.
**Before:** `Cola test 33cl` has **20** on both tablets.

**Steps:**
1. Cut the network on A and B.
2. **B, first:** stock out **3** of `Cola test 33cl`.
3. **A, after B (wait one minute):** « Ajustement de stock », « Quantité comptée » = **10**.
   « Enregistrer l'ajustement ».
4. Full round.

**Expected on A and B:** `Cola test 33cl` = **10**. (B took 3 **before** A counted, so A saw the
shelf already without them.)

**Result:** - [ ] OK   - [ ] KO — notes:

---

### ST3 — Same, but the stock out happens after the count

**Before:** `Cola test 33cl` = **20** on both (adjust it back online and sync first).

**Steps:**
1. Cut the network on A and B.
2. **A, first:** count `Cola test 33cl` = **10**.
3. **B, after A (wait one minute):** stock out **3**.
4. Full round.

**Expected on A and B:** `Cola test 33cl` = **7** (10 counted, then 3 out).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### ST4 — A delivery on A and a stock out on B at the same time

**Before:** `Eau test` known stock on both (write it down: **X**).

**Steps:**
1. Cut the network on A and B.
2. **A:** « Enregistrer une livraison » of `Eau test`: **24**, at a **new price** (higher than
   before).
3. **B:** stock out **6** of `Eau test`.
4. Full round.

**Expected on A and B:**
- `Eau test` = **X + 24 − 6**.
- The average cost is the same on A and B (look at the product page and the stock value on
  the dashboard).
- The price history of `Eau test` has the new price.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### ST5 — The dashboard numbers match

**Steps:**
1. After ST1–ST4, open « Tableau de bord » on A and on B.
2. Open « Rapports » on A and on B.

**Expected:** stock value, number of alerts, recent activity and report figures are **the
same** on both tablets.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 5. Orders

### OR1 — Created on A, received on B

**Goal:** an order moves between tablets through its whole life.

**Steps:**
1. **A:** « Commandes » → « Nouvelle commande ». Choose `Fournisseur Test`, add `Eau test` ×
   **24** and `Cola test 33cl` × **12**. « Envoyer la commande », confirm « Envoyer ».
2. **B:** open the same order. It shows « Envoyée ».
3. **B:** « Réceptionner la livraison ». Receive everything. Confirm.

**Expected on A and B:**
- The order is « Reçue ».
- The stock of both products went up by 24 and 12.
- The movements show the order reference.
- The page shows « Livraison reçue par … » with the name of the person on B.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OR2 — Partial delivery on one tablet, closing on the other

**Steps:**
1. **A:** new order to `Fournisseur Test`: `Eau test` × **24**. Send it. Sync.
2. **B:** « Réceptionner la livraison » with only **20**. Keep the order open (do not close the
   gap). Sync.
3. **A:** the order shows « Partielle » and « 4 en attente ». Tap « Clôturer la commande »,
   confirm « Clôturer ».

**Expected on A and B:** the order is closed, the stock went up by 20 only, and the gap of 4 is
still written on the order.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OR3 — Receive on A and receive again on B, both offline

**Goal:** two receipts of the same order are both kept (a receipt is never lost).
(SYNC_PLAN 11.2, points 3–5)

**Steps:**
1. **A:** new order `Cola test 33cl` × **12**, send it, Sync A then B.
2. Cut the network on A and B.
3. **A:** receive **12**.
4. **B:** receive **12** as well (B doesn't know A already did).
5. Full round.

**Expected on A and B:**
- Both receipts are in the « Réceptions » tab of the order.
- The stock went up by **24** (12 + 12), the same on both tablets.
- The order is « Reçue ».
- Write down how it looks: this is the "real delivery received twice by mistake" case. The
  manager can fix the stock with an adjustment.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### OR4 — The order status cannot go back

**Steps:**
1. **A:** new order, send it. Sync A then B.
2. Cut the network on B.
3. **A (online):** « Annuler la commande », confirm. Sync A.
4. **B (offline, the order still looks « Envoyée »):** « Réceptionner la livraison » and
   confirm.
5. Bring the network back on B. Sync B, then A.

**Expected:**
- On both tablets the order is « Annulée ».
- B's sync page shows, under « À vérifier », the refused change with the reason
  « La commande était déjà clôturée. » (or « Le statut de la commande ne peut pas revenir en
  arrière. »).
- Tap « Compris »: the message goes away.
- **Write down** what happened to the stock on B and on A for that receipt. Both tablets must
  show the **same** number.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 6. Catalog conflicts

### CA1 — The same field changed on both tablets

**Goal:** the last tablet to send wins. (SYNC_PLAN 11.2, point 4)

**Steps:**
1. Cut the network on A and B.
2. **A:** change the minimum stock of `Eau test` to **10**.
3. **B:** change the minimum stock of `Eau test` to **30**.
4. Bring the network back. **Sync A, then B**, then A.

**Expected on A and B:** minimum = **30** (B sent last).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### CA2 — Different products changed on both tablets

**Steps:**
1. Cut the network on A and B.
2. **A:** change the price of `Eau test`.
3. **B:** change the name of `Sel test` to `Sel fin test`.
4. Full round.

**Expected on A and B:** **both** changes are kept.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### CA3 — Deleted on A, edited on B: the delete wins

**Goal:** (SYNC_PLAN 11.2, point 6)
**Before:** create a supplier `Fournisseur Supprimé` online, Sync A and B.

**Steps:**
1. Cut the network on A and B.
2. **A:** delete `Fournisseur Supprimé`.
3. **B:** edit `Fournisseur Supprimé` (change its phone).
4. Bring the network back. **Sync A, then B**, then A.

**Expected:**
- `Fournisseur Supprimé` is gone on **both** tablets.
- B's sync page shows under « À vérifier »: « Fournisseur » with « Supprimé entre-temps sur un
  autre appareil. »

**Result:** - [ ] OK   - [ ] KO — notes:

---

### CA4 — The same category created on both tablets, then merged

**Steps:**
1. Cut the network on A and B.
2. **A:** create category `Boissons Froides`. Put `Eau test` in it.
3. **B:** create category `Boissons Froides` too. Put `Cola test 33cl` in it.
4. Full round.
5. **A:** open « Catégories et unités ».

**Expected:**
- Both tablets show a notice: « « Boissons Froides » existe en double, souvent parce qu'il a été
  créé sur deux tablettes hors ligne. » with a « Fusionner » button.
- Tap « Fusionner » on A, confirm. Sync A, then B.
- Only **one** `Boissons Froides` is left on both tablets, and it holds **both** products.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### CA5 — The same supplier linked twice to a product

**Steps:**
1. Make sure `Farine test 2` (create it) has **no** link to `Fournisseur Test`. Sync.
2. Cut the network on A and B.
3. **A:** add `Fournisseur Test` to `Farine test 2` at **1,00 €**.
4. **B:** add `Fournisseur Test` to `Farine test 2` at **1,20 €**.
5. Full round.

**Expected on A and B:**
- `Farine test 2` has `Fournisseur Test` **once**, with the same price on both tablets.
- The sync page shows under « À vérifier »: « Un fournisseur était lié deux fois au même
  article : le lien le plus récent a été gardé. »
- The product still has a default supplier.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 7. Photos

> A new photo does **not** push a live update. It arrives on the other tablet at its **next
> sync**. So in these tests, press Sync on the other tablet.

### PH1 — A product photo goes from A to B

**Goal:** (SYNC_PLAN 11.2, point 8)

**Steps:**
1. **A:** open `Eau test`, add a photo (camera or gallery). Save.
2. Sync A, then B.

**Expected:** B shows the same photo on `Eau test` (in the list and on the product page).

**Result:** - [ ] OK   - [ ] KO — notes:

---

### PH2 — Replace and remove a photo

**Steps:**
1. **B:** replace the photo of `Eau test` with another one. Sync B, then A.
2. **A:** remove the photo of `Eau test`. Sync A, then B.

**Expected:** after step 1, both show the **new** photo. After step 2, both show **no** photo.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### PH3 — A photo added offline

**Steps:**
1. Cut the network on A.
2. **A:** add a photo to `Cola test 33cl`. The sync page shows the photo waiting.
3. Bring the network back. Sync A, then B.

**Expected:** B shows the photo.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### PH4 — An employee photo

**Steps:**
1. **A:** « Gestion Employée » → an employee → add a photo. Sync A, then B.

**Expected:** B shows the same employee photo.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 8. Staff, attendance and pay

### 8.0 Test data for this part

On tablet **A**, online, in the same store, create:

| Name | Role | E-mail | PIN | Hourly rate |
|---|---|---|---|---|
| Léa Test | Gérant | `lea@test.be` | `11.11.11-111.11` | 20 € |
| Karim Test | Employé | `karim@test.be` | `22.22.22-222.22` | 15 € |
| Sara Test | Employé | `sara@test.be` | `33.33.33-333.33` | 15 € |

Sync A, then B. Check that **B shows the three people**.

"Notifications" below means the bell, filter « Personnel ».

### Login (e-mail + PIN)

#### L1 — A manager created on A logs in on B
**Steps:**
1. **B:** log out of the current person, then log in with `lea@test.be` and `11.11.11-111.11`.

**Expected:** the login works and opens the dashboard of the store.
**Result:** - [ ] OK   - [ ] KO — notes:

#### L2 — Wrong PIN, no lock
**Steps:**
1. **B:** log in with `lea@test.be` and a **wrong** PIN, **5 times** in a row.
2. Then use the right PIN.

**Expected:** « E-mail ou numéro PIN incorrect. » each time. The 6th try with the right PIN
works (there is no lock).
**Result:** - [ ] OK   - [ ] KO — notes:

#### L3 — An employee cannot open the app
**Steps:**
1. **B:** log in with `karim@test.be` and `22.22.22-222.22`.

**Expected:** refused, with a message that he has no access to the app.
**Result:** - [ ] OK   - [ ] KO — notes:

#### L4 — A role changed on A works on B
**Steps:**
1. **A:** edit Karim → « Tarif et rôle » → Gérant → save. Sync A, then B.
2. **B:** log in with `karim@test.be` and his PIN.
3. Afterwards, set Karim back to Employé and sync.

**Expected:** step 2 works.
**Result:** - [ ] OK   - [ ] KO — notes:

#### L5 — A removed person cannot log in
**Steps:**
1. **A:** remove Léa (her card → « Retirer »). Sync A, then B.
2. **B:** log in with `lea@test.be` and her PIN.
3. Afterwards, restore Léa and sync.

**Expected:** refused with « Ce compte a été retiré de l'équipe… ».
**Result:** - [ ] OK   - [ ] KO — notes:

### Clock-in board

#### P1 — Clock-in on both tablets
**Goal:** (SYNC_PLAN 11.2, point 3 "a clock-in", and the double clock-in)
**Steps:**
1. Cut the network on A and B.
2. **A:** Karim → « Pointer » at about 09:00 (confirm with his PIN).
3. **B:** Karim → « Pointer » at about 09:03.
4. Full round.

**Expected on A and B:**
- **One** day for Karim, with **two** arrivals (09:00 and 09:03).
- A notification « Double pointage : Karim Test ».
- In the attendance history → Karim's day: a block « Pointage en double » with
  « Supprimer ce pointage en double ».

**Then:**
5. **A:** « Fin de journée » for Karim. Full round.
   **Expected:** **both** arrivals are closed at the same time, status « Terminé » on A and B.
6. **B:** delete the double clock-in (confirm). Full round.
   **Expected:** only one arrival is left, on both tablets.

**Result:** - [ ] OK   - [ ] KO — notes:

#### P3 — Break on one tablet, leave on the other
**Before:** Karim is « En service » on both tablets (clock in online, then sync).
**Steps:**
1. Cut the network on A and B.
2. **A:** Karim → « Pause » at 12:00.
3. **B:** Karim → « Fin de journée » at 12:30.
4. Full round.

**Expected on A and B:** Karim is « Terminé » (not « En pause »). The break ends at 12:30 in the
hours.
**Result:** - [ ] OK   - [ ] KO — notes:

#### P4 — Two different leave times for the same arrival
**Before:** Karim is « En service » on both tablets.
**Steps:**
1. Cut the network on A and B.
2. **A:** Karim → « Fin de journée » at 17:00.
3. **B:** Karim → « Fin de journée » at 17:30.
4. Full round.

**Expected on A and B:** the leave time kept is **17:00** (the earliest), and a notification
« Deux départs : Karim Test » appears (the gap is more than 15 minutes).

**Variant:** do it again with 17:00 and 17:10. **Expected:** 17:00 kept, **no** notification
(gap 15 minutes or less).

**Result:** - [ ] OK   - [ ] Variant OK   - [ ] KO — notes:

#### P5 — The service day opened on both tablets
**Before:** today's service day is not open yet.
**Steps:**
1. Cut the network on A and B.
2. **A:** Karim → « Pointer » (this opens the day on A).
3. **B:** Sara → « Pointer » (this opens the day on B).
4. Full round.

**Expected on A and B:** **one** open service day. Karim and Sara are both « En service ». No
clock-in is lost.
**Result:** - [ ] OK   - [ ] KO — notes:

#### P6-a — Day closed on A while someone is still working on B
**Before:** the day is open and synced.
**Steps:**
1. Cut the network on **B only**.
2. **B:** Sara → « Pointer » at 16:00 (A doesn't know).
3. **A (online):** end the day of everyone A sees as working, then « Fermer la journée » at
   17:30.
4. Full round.

**Expected on A and B:**
- The day stays **closed**.
- Sara's day has a leave time of **17:30** (the closing time), status « Terminé ».
- A notification « Pointage après la fermeture : Sara Test », saying her leave is set to 17:30.

**Variant:** Sara is on **break** on B when A closes. **Expected:** the break also stops at 17:30.
**Result:** - [ ] OK   - [ ] Variant OK   - [ ] KO — notes:

#### P6-b — Clock-in on B **after** the day was closed on A
**Before:** the day is open and synced.
**Steps:**
1. Cut the network on B.
2. **A (online):** « Fermer la journée » at 17:30.
3. **B (still thinks the day is open):** Karim → « Pointer » at 17:45.
4. Full round.

**Expected on A and B:**
- The day stays closed.
- The 17:45 clock-in is **gone** (if Karim had nothing else that day, his day is gone too).
- A notification « Pointage après la fermeture : Karim Test », saying the 17:45 arrival is not
  counted.
**Result:** - [ ] OK   - [ ] KO — notes:

#### P6-c — Known limit (just observe, not a bug)
**Before:** Karim is working, synced.
**Steps:**
1. Cut the network on B.
2. **A:** « Fermer la journée » at 17:30, giving Karim a leave time of 17:30.
3. **B:** Karim → « Fin de journée » at 18:00.
4. Full round.

**Expected:** the earliest leave time (17:30) is kept (rule P4), with a notification
« Deux départs ». Write down what you see.
**Observed:**

### Attendance history

#### H1 — Two managers fix the same forgotten leave time
**Before:** one day of Karim has no leave time (for example yesterday, arrival 09:00), synced.
**Steps:**
1. Cut the network on A and B.
2. **A (logged in as Léa):** attendance history → that day → « Corriger la sortie » → 17:00.
3. **B (logged in as the owner):** same day → « Corriger la sortie » → 18:00.
4. Full round.

**Expected on A and B:** the leave time is **17:00**, saved under the name of the person who
typed it. The notification « Deux départs : Karim Test » **always** appears here, whatever the
gap, because it is a correction.
**Result:** - [ ] OK   - [ ] KO — notes:

#### H2 — A manager's fix against the employee's own leave
**Before:** Karim is working, synced.
**Steps:**
1. Cut the network on A and B.
2. **A:** Karim → « Fin de journée » at 17:40.
3. **B:** a manager fixes the leave time of that day to 17:20 (if this is not offered for
   today, do this test on a day left open since yesterday).
4. Full round.

**Expected on A and B:** 17:20 (the earliest) is kept, with the notification « Deux départs ».
**Result:** - [ ] OK   - [ ] KO — notes:

#### H3 — Delete a double clock-in on a day already paid
**Steps:**
1. Make a day with two arrivals again (as in P1), then **pay** it (see PA1). Sync.
2. **A:** attendance history → that day → « Supprimer ce pointage en double ».

**Expected:** it is not possible (the button is not shown, or it is refused saying the day
changed in the meantime / is paid). Nothing changes.
**Result:** - [ ] OK   - [ ] KO — notes:

### Pay

#### PA1 — The same employee paid on both tablets
**Goal:** (SYNC_PLAN 11.2, point 7)
**Before:** Karim has 2 finished, unpaid days, synced on A and B.
**Steps:**
1. Cut the network on A and B.
2. **A:** pay history → Karim → « Payer » these 2 days (confirm with the PIN).
3. **B:** « Payer » the same 2 days.
4. Bring the network back. **Sync A first**, then B, then A.

**Expected on A and B:**
- The days are paid by **A's payment** (the first one to reach the server).
- B's payment **still exists**, marked « Paiement en double », with the **overpaid** amount
  (the days paid twice).
- A notification « Paiement en double : Karim Test ».
- B's sync page, under « À vérifier »: « Ce jour avait déjà été payé sur une autre tablette :
  il reste sur ce premier paiement… ». No blocking error.

**Variant:** B pays only **1** of the 2 days. **Expected:** the overpaid amount counts only that
day.
**Result:** - [ ] OK   - [ ] Variant OK   - [ ] KO — notes:

#### PA2 — A change arrives on a day already paid
**Before:** Karim has a finished day (09:00 → 17:00), unpaid, synced.
**Steps:**
1. Cut the network on A.
2. **B (online):** pay that day. Sync B.
3. **A (offline, doesn't know it is paid):** fix that day (leave at 18:00 instead of 17:00, or
   add a break).
4. Bring the network back on A. Sync A, then B.

**Expected on A and B:**
- The day keeps **17:00**. The amount paid doesn't change.
- On A, the change is **undone** and the day goes back to the server's version.
- A notification « Jour déjà payé : Karim Test », with the difference (for example « 1h00 non
  payée »).
- A's sync page explains: « Ce jour est déjà payé : la modification n'a pas été appliquée. »
**Result:** - [ ] OK   - [ ] KO — notes:

#### E6 — The hourly rate changes during a payment
**Steps:**
1. Cut the network on A and B.
2. **A:** change Karim's rate from 15 € to 18 €.
3. **B:** pay some days of Karim (at 15 €).
4. Full round.

**Expected:** B's payment stays **at 15 €**. Karim's card says **18 €**. No conflict.
**Result:** - [ ] OK   - [ ] KO — notes:

### Employees

#### E1-a — The same ID number added on both tablets, same store
**Steps:**
1. Cut the network on A and B.
2. **A:** add « Nora Test », PIN `44.44.44-444.44`, e-mail `nora@test.be`, phone
   `0470 11 11 11`, rate 15 €, Employé. Clock her in.
3. **B:** add « Nora Test », **same PIN**, e-mail `nora2@test.be`, phone `0470 22 22 22`, rate
   16 €, Gérant. Clock her in too.
4. Full round.

**Expected on A and B:**
- **One** card « Nora Test » in the staff list.
- Her clock-ins from both tablets are on this card (the same day makes only one day).
- The role kept is the **most limited** one (Employé). The rate is the one of the card kept.
- A notification « Employé ajouté deux fois : Nora Test », mentioning the rate and role
  difference.
**Result:** - [ ] OK   - [ ] KO — notes:

#### E1-b — The same ID number in two different stores
**Before:** the restaurant has two stores (see part 10).
**Steps:**
1. Cut the network on A and B.
2. **A (store 1):** add « Omar Test », PIN `55.55.55-555.55`.
3. **B (store 2):** add « Omar Test », same PIN.
4. Full round.

**Expected:** **two** cards, one per store, nothing merged, and a notification « Même CIN dans
deux établissements : Omar Test ».
**Result:** - [ ] OK   - [ ] KO — notes:

#### E2-a — Two different fields changed
**Steps:**
1. Cut the network on A and B.
2. **A:** change Sara's **phone**.
3. **B:** change Sara's **name** (for example « Sara Test-Modif »).
4. Full round.

**Expected on A and B:** **both** changes are kept, no notification.
**Result:** - [ ] OK   - [ ] KO — notes:

#### E2-b — The same field changed on both sides (rate)
**Steps:**
1. Cut the network on A and B.
2. **A:** Sara's rate → 17 €.
3. **B:** Sara's rate → 19 €.
4. Bring the network back. Sync **A, then B**, then A.

**Expected on A and B:** **19 €** (B sent last), and a notification « Fiche modifiée sur deux
tablettes : Sara Test » about the hourly rate.

**Variant (role):** A makes Sara Gérant, B sets her back to Employé. **Expected:** the last one
sent wins, with a notification about the role.
**Result:** - [ ] OK   - [ ] Variant OK   - [ ] KO — notes:

#### E2-c — Changed on A, synced, then changed on B (not a conflict)
**Steps:**
1. **A (online):** Sara's rate → 17 €. Sync A, then B.
2. **B:** Sara's rate → 18 €. Sync B, then A.

**Expected:** 18 €, and **no** notification (B had seen A's change).
**Result:** - [ ] OK   - [ ] KO — notes:

#### E3 — Removed on A, edited on B
**Steps:**
1. Cut the network on A and B.
2. **A:** remove Sara.
3. **B:** change Sara's phone.
4. Full round.

**Expected on A and B:** Sara stays **removed**, with the new phone.
**Result:** - [ ] OK   - [ ] KO — notes:

#### E4 — Removed on A while clocking in on B
**Steps:**
1. Cut the network on A and B.
2. **A:** remove Karim.
3. **B:** Karim → « Pointer », then « Fin de journée » later.
4. Full round.
5. Afterwards, restore Karim.

**Expected on A and B:**
- Karim stays removed, but **his hours are kept**.
- In the pay history, Karim shows as « Retiré », with these hours still to pay.
- A notification « Pointage après le retrait : Karim Test ».
**Result:** - [ ] OK   - [ ] KO — notes:

#### E5 — Removed on A, removed then restored on B
**Steps:**
1. Cut the network on A and B.
2. **A:** remove Sara.
3. **B:** remove Sara, then **restore** her.
4. Bring the network back. Sync **A, then B**, then A.

**Expected on A and B:** Sara is **active** (B's last decision wins), with a notification
« Fiche modifiée sur deux tablettes : Sara Test ».
**Result:** - [ ] OK   - [ ] KO — notes:

#### S1 — One notification, read separately by each person
**Steps:**
1. Use any test above that creates a notification (for example P4).
2. **A, logged in as the manager (Léa):** open the notification.
3. **A and B, logged in as the owner:** look at the same notification.

**Expected:**
- The notification shows **once** on each tablet, even if both tablets settled the conflict.
- Tapping it opens the employee's history (or the pay page for PA1/PA2).
- After Léa reads it, it is still **unread for the owner**, on A and on B.
- There is no setting to turn off « Personnel » notifications.
**Result:** - [ ] OK   - [ ] KO — notes:

---

## 9. Alerts and notifications

### AL1 — A low stock made on A shows on B

**Steps:**
1. **A:** stock out `Eau test` until it is **under its minimum** (not zero).
2. Wait a few seconds.

**Expected on A and B:**
- « Alertes »: `Eau test` is in « Stock bas », and the count « N produits en alerte » is the same.
- The bell has a « Stock faible » notification on both.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AL2 — Out of stock

**Steps:**
1. **B:** stock out the rest of `Eau test` (stock = 0).

**Expected on A and B:** `Eau test` is in « Ruptures » in « Alertes », and there is a
« Rupture de stock » notification.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AL3 — Create orders from the alerts

**Steps:**
1. **A:** « Alertes » → select the products → « Commander ».
2. Sync A, then B.

**Expected:** a draft order (« Brouillon ») is created per supplier, and B shows it. In
« Alertes », the products now say « En commande » on both tablets.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AL4 — Push on the owner's phone (only if push is set up on the dev server)

**Before:** the owner's Android phone has the app, is signed in to the account, and the
**owner** is logged in on it. Notifications are allowed on the phone.

**Steps:**
1. Put the phone app in the background (or lock the phone).
2. **A:** make one product **out of stock**.
3. **A:** make **3 other** products go under their minimum, within one minute.
4. **B, logged in as the manager:** watch for pushes on a manager's phone, if you have one.

**Expected:**
- Step 2: a push « Rupture de stock : … » arrives at once.
- Step 3: about **two minutes** later, **one** grouped push « Stock faible : 3 produits ».
- Tapping a stock push opens the store's « Alertes ».
- The manager gets **no** push.
- With « Paramètres » → « Notifications » → « Stock faible » turned **off**, a new low stock
  sends **no** push.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### AL5 — An offline tablet's alert is pushed when it reconnects

**Steps:**
1. Cut the network on B.
2. **B:** make a product out of stock.
3. Wait 5 minutes, then bring the network back on B.

**Expected:** no push while B is offline. The push arrives when B reconnects.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 10. Several stores in one restaurant

### MS1 — A second store

**Steps:**
1. **A (owner):** create a second store, for example `Test Bistro`.
2. Sync A, then B.

**Expected:** on both tablets, « Changer d'établissement » shows the two stores.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### MS2 — Data stays in its own store

**Steps:**
1. **A:** switch to `Test Bistro`. Create a product `Bistro test` and a supplier.
2. **B:** stay on the first store.
3. Sync A, then B.

**Expected:**
- On B, the first store does **not** show `Bistro test`.
- On B, switching to `Test Bistro` shows `Bistro test`.
- Alerts, orders, movements and staff of one store never show in the other.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### MS3 — Two tablets in two different stores at the same time

**Steps:**
1. **A:** on `Test Brasserie`. **B:** on `Test Bistro`.
2. Cut the network on both. Make stock outs on each one.
3. Full round. Then switch each tablet to the other store.

**Expected:** each store has exactly its own changes, the same on both tablets.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### MS4 — Only the owner can change a store

**Steps:**
1. **B (manager):** try to edit the store settings (« Paramètres » → « Établissement »: name or
   address). Sync B.

**Expected:** either the manager cannot edit them, or the change is refused and B's sync page
shows « Seul le propriétaire peut modifier un établissement. » A keeps the old values.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 11. Three devices and a busy day (optional, recommended)

### TD1 — A third device joins

**Steps:**
1. On device **C** (Windows PC or a third tablet), sign in with a manager account of the
   restaurant (invite one more manager if needed).

**Expected:** C downloads everything and shows the same data as A and B. Write down how long the
first download takes: ______

**Result:** - [ ] OK   - [ ] KO — notes:

---

### TD2 — Everyone offline, reconnect in random order

**Steps:**
1. Cut the network on A, B and C.
2. On each one, for 15 minutes, work like a real service: stock outs, one delivery, one new
   product, one price change, clock-ins and leave times for 2 people.
3. Bring the network back in this order: **C, then A, then B**. Sync each one, then sync all
   three again.

**Expected:**
- The three devices show **exactly** the same stock for every product, the same orders, the
  same hours.
- Every movement from every device is in « Mouvements de stock ».
- Any conflict appears once, as a notification or under « À vérifier », with a clear message.

**Result:** - [ ] OK   - [ ] KO — notes:

---

### TD3 — The app stays smooth while syncing

**Steps:**
1. While TD2's sync is running, scroll through « Produits » and open a few products.

**Expected:** the screens never freeze or wait for the network.

**Result:** - [ ] OK   - [ ] KO — notes:

---

## 12. Summary

| Code | Test | Expected message | OK / KO | Notes |
|---|---|---|---|---|
| AC1 | Owner creates restaurant on A | — | | |
| AC2 | Account errors | error texts | | |
| AC3 | Manager joins on B with a code | — | | |
| AC4 | Code used twice / wrong code | « Code invalide ou expiré. » | | |
| AC5 | Device list | — | | |
| AC6 | Demo stays local | « Démonstration — rien n'est envoyé » | | |
| AC7 | Demo device joins account | demo wipe warning | | |
| AC8 | Own data, account already full | backup file | | |
| AC9 | Owner removes a device | device removed message | | |
| AC10 | Sign out wipes tablet | pending changes warning | | |
| BS1 | Created on A, seen on B (live) | — | | |
| BS2 | Edited on B, seen on A | — | | |
| BS3 | Deleted on A, gone on B | — | | |
| BS4 | Kill app and reopen | — | | |
| OF1 | Offline banner and count | « Serveur injoignable » | | |
| OF2 | Network back, auto send | — | | |
| OF3 | App closed while offline | — | | |
| OF4 | Long time offline | — | | |
| ST1 | Two stock outs offline | — | | |
| ST2 | Count after stock out | — | | |
| ST3 | Count before stock out | — | | |
| ST4 | Delivery + stock out | — | | |
| ST5 | Dashboard numbers match | — | | |
| OR1 | Order created on A, received on B | — | | |
| OR2 | Partial delivery, closed on A | — | | |
| OR3 | Received twice offline | — | | |
| OR4 | Status cannot go back | « À vérifier » | | |
| CA1 | Same field on both | — | | |
| CA2 | Different products on both | — | | |
| CA3 | Delete wins | « Supprimé entre-temps… » | | |
| CA4 | Duplicate category, merge | « Fusionner » | | |
| CA5 | Supplier linked twice | « À vérifier » | | |
| PH1 | Photo A → B | — | | |
| PH2 | Replace and remove photo | — | | |
| PH3 | Photo offline | — | | |
| PH4 | Employee photo | — | | |
| L1–L5 | Staff login | see each test | | |
| P1 | Clock-in on both | Double pointage | | |
| P3 | Break on A, leave on B | — | | |
| P4 | Two leave times | Deux départs / none | | |
| P5 | Day opened on both | — | | |
| P6-a | Closed while working | Pointage après la fermeture | | |
| P6-b | Clock-in after closing | Pointage après la fermeture | | |
| P6-c | Leave after closing (limit) | Deux départs | | |
| H1 | Two fixes of one leave | Deux départs | | |
| H2 | Fix vs own leave | Deux départs | | |
| H3 | Double on a paid day | — (refused) | | |
| PA1 | Paid on both | Paiement en double | | |
| PA2 | Change on a paid day | Jour déjà payé | | |
| E6 | Rate changed during payment | — | | |
| E1-a | Same ID, same store | Employé ajouté deux fois | | |
| E1-b | Same ID, two stores | Même CIN dans deux établissements | | |
| E2-a | Different fields | — | | |
| E2-b | Same field (rate / role) | Fiche modifiée sur deux tablettes | | |
| E2-c | One after the other | — | | |
| E3 | Removed on A, edited on B | — | | |
| E4 | Removed on A, clocks in on B | Pointage après le retrait | | |
| E5 | Removed on A, restored on B | Fiche modifiée sur deux tablettes | | |
| S1 | One notification, read per person | — | | |
| AL1 | Low stock A → B | Stock faible | | |
| AL2 | Out of stock | Rupture de stock | | |
| AL3 | Orders from alerts | — | | |
| AL4 | Owner phone push | push | | |
| AL5 | Push after reconnect | push | | |
| MS1 | Second store | — | | |
| MS2 | Data stays in its store | — | | |
| MS3 | Two stores at once | — | | |
| MS4 | Only owner edits a store | « Seul le propriétaire… » | | |
| TD1 | Third device joins | — | | |
| TD2 | Three devices offline | — | | |
| TD3 | Smooth while syncing | — | | |

### Sign-off

| | |
|---|---|
| Tester | |
| Date | |
| App version / commit | |
| Server (dev project) | |
| Devices used | |
| Result | ☐ Ready to deliver   ☐ Not ready (see KO list) |
