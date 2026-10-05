# Synchronisation du personnel : ce qui a été modifié

Ce fichier explique ce qui a été fait pour `SYNC_PERSONNEL_PLAN.md` (étapes 1 à 8), sur la branche
`feat/sync-personnell-system`. Il suit l'ordre du travail. Pour chaque étape :

- **le problème** : ce qui n'allait pas avec deux tablettes ;
- **la règle** : ce qui a été validé dans le plan ;
- **ce qui a changé** : les fichiers, et le code en résumé ;
- **les tests** : où la règle est vérifiée.

`SYNC_PERSONNEL_PLAN.md` est le plan (les règles validées). `SYNC_EXPLAINED.md` explique la
synchronisation de base (phases 1 à 10). Ce fichier explique ce qui a été ajouté par-dessus pour le
personnel.

**Périmètre : uniquement** les employés, le tableau de pointage, l'historique de pointage, le
paiement et les identifiants de connexion. Le stock, les fournisseurs et le catalogue ne changent pas.

---

## 0. En une minute

Quatre principes, appliqués partout :

1. **On ne perd jamais une heure travaillée ni un paiement réellement versé.**
2. **Toutes les tablettes appliquent la même règle**, donc elles finissent avec les mêmes données.
3. **Sans gravité → réglé tout seul. Douteux → gardé et signalé** au gérant et au propriétaire.
4. **Le serveur reste un miroir.** Il ne refuse que ce qui ne fait rien perdre (un jour déjà payé).

Où se règlent les conflits :

```
 Tablette A                         Supabase                          Tablette B
 ──────────                         ────────                          ──────────
 modification ──► outbox ──push──► push_changes ──────pull──────────► SyncApplier
   (trigger)      + colonnes         écrit seulement les              applique la règle
                    modifiées        colonnes modifiées               (fusion, le plus tôt,
                  + valeur d'avant   refuse : jour déjà payé           statut recalculé…)
                                     répond : « overwrote »,          et signale si besoin
 SyncRunner  ◄────answer────────────  « restore »
 remet la version du serveur,
 signale (paiement en double…)
```

Les commits, dans l'ordre :

| Étape | Commit | Sujet |
|---|---|---|
| 1 | `3f2655e` | Fusion de `feat/sync-data`, schéma v21 |
| 2 | `c2be947` | La journée de service se synchronise (P5) |
| 3 | `d3a4125` | Les signalements |
| 4 | `71b01bb` | Seuls les champs modifiés partent (E2, E3) |
| 5 | `996e4e7` | Les identifiants (C1–C4) |
| 6 | `3d78af3` | Tableau et historique de pointage (P1, P3, P4, P6, H1, H2) |
| 7 | `2b47861` | Le paiement (PA1, PA2) |
| 8 | `f840814` | Les employés (E1, E2, E4, E5) |
| — | `39f7ae0` | Test complet des étapes 1 à 8 |

---

## Étape 1 : finir la fusion (schéma v21)

**Le problème.** La branche réunit deux branches qui avaient chacune leurs versions v14 à v16 du
schéma : la synchro (`14-sync-phase-1`, jusqu'à v20) et l'audit du pointage (`feat/sync-data`).
Les mêmes numéros décrivaient des choses différentes.

**Ce qui a changé.**

- **Schéma v21** : les trois changements de l'audit passent **après** la synchro :
  - la table `business_days` (la journée de service) ;
  - `stores.business_day_auto_open_minutes` (l'heure d'ouverture automatique, 05:00 par défaut) ;
  - `attendance_sessions.exit_set_by_employee_id` (qui a saisi un départ à la place de l'employé).
- **Un plantage de mise à jour évité** : la migration v15 reconstruit les tables avec leur forme
  actuelle. Elle aurait cherché les nouvelles colonnes avant qu'elles existent. Maintenant, une
  colonne absente de l'ancienne table démarre à sa valeur par défaut, et la v21 n'ajoute une
  colonne que si elle manque (`_addColumnIfMissing`).
- **Les lignes supprimées par la synchro** sont ignorées partout dans le code de l'audit
  (filtre `deletedAt.isNull()`).
- **`dayOf`** n'existe plus qu'à un seul endroit (`core/utils/dates.dart`).

**Fichiers** : `lib/data/database/app_database.dart` (migrations), `attendance_assembler.dart`,
`payroll_repository.dart`, `attendance_repository.dart`, `busy_calendar.dart`.

**À savoir** : un appareil de test qui a tourné sur `feat/sync-data` (sa propre v16) doit être
réinstallé.

---

## Étape 2 : la journée de service se synchronise

**Le problème.** La journée de service (ouverte au premier pointage, fermée par le gérant) n'était
connue que de la tablette qui l'avait ouverte.

**La règle P5.** Une journée ouverte sur deux tablettes → **une seule gardée** (le plus petit
identifiant) ; aucun pointage ne bouge.

**Ce qui a changé.**

- `business_days` devient une table synchronisée : colonnes `updated_at` / `deleted_at`, trigger
  `*_touch`, triggers outbox, entrée dans `SyncTables.synced`.
- L'unicité « une journée par établissement et par date » ne compte plus que les lignes vivantes
  (index partiel dans `sync_indexes.drift`).
- `SyncApplier._applyBusinessDay` applique P5. **La fermeture n'est jamais perdue** : si seule la
  journée écartée était fermée, la journée gardée reprend sa fermeture.
- `BusinessDayRepository` : si la synchro amène deux journées ouvertes, c'est la plus récente qui
  sert (au lieu de planter).
- Les deux nouvelles colonnes partent aussi au serveur.

**Serveur** : `supabase/migrations/20261003000100_personnel_audit.sql`.

---

## Étape 3 : les signalements

**Le problème.** Le plan dit souvent « signalé au gérant et au propriétaire ». Il fallait **un seul
moyen** de le faire, visible sur toutes les tablettes.

**Ce qui a changé.**

- Un signalement est une **notification de type `personnel`**, créée par
  `AccountRepository.signal(...)`. Les notifications étant déjà synchronisées, il arrive sur toutes
  les tablettes.
- **Dans la cloche existante**, avec un filtre « Personnel ». Aucun réglage ne permet de les couper.
  Un appui ouvre l'historique de l'employé, ou sa page Paiement pour un signalement de paiement
  (`notifications.related_target`).
- **Un seul signalement par situation** : son identifiant est calculé à partir de la situation
  (`'flag-' + sha1(clé)`, par exemple `double_clock_in:<journée gardée>`). Deux tablettes qui
  règlent le même conflit créent donc la même ligne, pas deux.
- **Lu séparément** par le gérant et le propriétaire : colonnes `read_by_manager_at` et
  `read_by_owner_at`. À la réception, un « lu » déjà présent n'est jamais perdu. Les autres
  notifications (stock, livraisons…) restent lues pour tout le monde.

```dart
await AccountRepository(db).signal(
  storeId: storeId,
  key: 'double_clock_in:$keptId',      // la même clé sur toutes les tablettes
  title: 'Double pointage : $name',
  body: '…',
  employeeId: employeeId,
  target: 'payroll',                   // facultatif : ouvre la page Paiement
);
```

**Fichiers** : `account_repository.dart`, `tables/account.dart`, `notification_item.dart`,
`account_mapper.dart`, `notifications_page.dart`, `providers.dart` (le rôle de la personne
connectée).

---

## Étape 4 : seuls les champs modifiés partent (E2, E3)

**Le problème.** Une modification envoyait toute la ligne. Si A changeait le téléphone de Karim et
B son nom, la dernière arrivée écrasait l'autre.

**Les règles.**
- E2 : deux modifications de la même fiche → seuls les champs modifiés sont envoyés ; même champ →
  le dernier gagne.
- E3 : archivé d'un côté, modifié de l'autre → reste archivé.

**Ce qui a changé.**

- **`outbox.changed_columns`** : la liste JSON des colonnes réellement modifiées. Le trigger de
  modification compare `NEW` et `OLD` colonne par colonne. Plusieurs modifications hors ligne
  s'additionnent. Une ligne neuve reste entière (`null` = tout).
- Concerne les tables du personnel : `employees`, `employee_credentials`, `payroll_periods`,
  `attendances`, `attendance_sessions`, `attendance_pauses`, `business_days`, `notifications`. Les
  autres tables envoient toujours la ligne entière.
- L'envoi porte `columns`. Le serveur n'écrase que ces colonnes (et `updated_at`).

```sql
-- extrait du trigger généré (outbox_triggers.drift)
(SELECT json_group_array(c) FROM (
   SELECT 'phone' AS c WHERE NEW.phone IS NOT OLD.phone
   UNION ALL SELECT 'last_name' AS c WHERE NEW.last_name IS NOT OLD.last_name …))
```

**Fichiers** : `tool/generate_outbox_triggers.py` (liste `PARTIAL`), `tables/outbox.dart`,
`sync_service.dart`, `test/support/fake_account_backend.dart` (le faux serveur des tests).

**Serveur** : `supabase/migrations/20261003000200_partial_updates.sql`.

---

## Étape 5 : les identifiants (C1 à C4)

**Le problème.** Une connexion réécrivait toute la ligne du mot de passe (essais ratés, dernière
connexion) et pouvait remettre un ancien mot de passe changé entre-temps sur une autre tablette.

**Les règles.**
- C1 : seul le mot de passe est partagé ; essais ratés, blocage et dernière connexion restent sur
  chaque tablette.
- C2 : mot de passe changé sur deux tablettes → le dernier gagne et c'est signalé.
- C3 : le blocage après trop d'erreurs est propre à chaque tablette.
- C4 : l'ancien mot de passe fonctionne sur une tablette hors ligne jusqu'à la synchro (normal).

**Ce qui a changé.**

- **Nouvelle table locale `login_states`** (jamais synchronisée) : `failed_attempts`,
  `locked_until`, `last_login_at`. La migration v21 y recopie ce qui existait, puis retire ces trois
  colonnes de `employee_credentials`.
- Un nouveau mot de passe, posé ici ou reçu par la synchro, lève le blocage de la tablette.
- **Détection de C2 : la valeur d'avant voyage avec la modification.** `outbox.base_values` contient,
  pour quelques colonnes surveillées, la valeur avant la première modification en attente. Si le
  serveur a entre-temps une autre valeur (changée ailleurs, sans que cette tablette l'ait vue), il
  accepte quand même et répond `overwrote: ['password_hash']`. La tablette crée alors le
  signalement. Colonnes surveillées : le mot de passe, le taux horaire, le rôle et le retrait
  (étape 8).

**Fichiers** : `tables/login_states.dart`, `credential_repository.dart`, `credential_mapper.dart`,
`tool/generate_outbox_triggers.py` (liste `WATCHED`), `auth_service.dart` (`PushResult.overwrote`),
`sync_service.dart` (`_signalOverwrite`).

**Serveur** : `supabase/migrations/20261003000300_credentials.sql`.

---

## Étape 6 : tableau et historique de pointage

| Règle | Situation | Ce qui se passe |
|---|---|---|
| P1 | Arrivée pointée sur deux tablettes | une seule journée, les deux arrivées gardées ; **le départ ferme toutes les arrivées ouvertes** ; signalé ; nouvelle action « Supprimer ce pointage en double » |
| P3 | Pause sur une tablette, départ sur l'autre | le statut n'est plus copié, il est **recalculé à partir des heures** ; une pause sans fin s'arrête au départ |
| P4 | Deux départs pour la même arrivée | le **plus tôt** est gardé partout ; signalé si l'écart dépasse 15 min |
| H1 / H2 | Deux gérants corrigent le même départ, ou un gérant contre l'employé | le plus tôt gagne, **toujours signalé** (c'est une correction) |
| P6 | Journée fermée sur une tablette, pointage sur l'autre | **la fermeture gagne** : une arrivée encore ouverte reçoit un départ à l'heure de fermeture (une pause en cours s'arrête aussi) ; une arrivée pointée **après** la fermeture est supprimée, avec sa journée s'il n'y reste rien ; chaque cas est signalé. Un jour déjà payé n'est pas touché, seulement signalé |

**Ce qui a changé.**

- `AttendanceRepository.refreshStatus` calcule le statut (au travail / en pause / terminé) à
  partir des arrivées et des pauses. La synchro l'appelle après chaque journée, arrivée ou pause
  reçue.
- `pausesOf(session)` (`core/utils/attendance_status.dart`) : une pause jamais terminée s'arrête au
  départ, dans le calcul des heures et dans la ligne d'historique.
- `clockOut` et la fermeture de la journée (`endShift`) ferment **toutes** les arrivées ouvertes du
  jour.
- `deleteDuplicateSession` + un bloc « Pointage en double » dans le tiroir de l'historique
  (gérant et propriétaire, confirmation et PIN). L'action est refusée sur un jour payé ou s'il ne
  reste qu'une arrivée.
- `SyncApplier` : `_applySessionExit` (le départ le plus tôt ; la tablette qui l'avait le remet et
  le renvoie), `_applyPause` (la fin de pause la plus tôt), `_settlePunchesAfterClose` (P6, avec
  `_endSessionAt` et `_removeSession`). Le départ mis à la fermeture porte comme auteur la personne
  qui a fermé la journée, comme une correction.

**Fichiers** : `attendance_repository.dart`, `sync_applier.dart`, `attendance_status.dart`,
`attendance_history_page.dart`, `attendance_row.dart`, `models/attendance.dart` (identifiant de
l'arrivée).

---

## Étape 7 : le paiement (PA1, PA2)

**Le problème.** Le refus `already_paid` ne protégeait qu'une période de paie. Deux tablettes qui
payaient les mêmes jours créaient deux périodes, et chaque jour prenait le lien arrivé en dernier.

**Les règles.**
- PA1 : même employé payé sur deux tablettes → le premier paiement arrivé au serveur garde les
  jours ; le second est gardé, marqué « paiement en double », et le trop-versé est signalé.
- PA2 : changement arrivé sur un jour déjà payé → le jour est gelé, le montant ne change pas ; le
  changement n'est pas appliqué mais il est signalé avec la différence.

**Ce qui a changé.**

- **Serveur** : deux nouveaux refus.
  - `day_already_paid` (PA1) : un jour garde le paiement arrivé le premier.
  - `paid_day_frozen` (PA2) : un jour payé, ses arrivées et ses pauses ne bougent plus. Un
    changement qui ne modifie rien (un renvoi) passe quand même.

  Avec son refus, le serveur renvoie **`restore`**, les lignes telles qu'il les a.
- **Tablette** (`SyncRunner._settleRefusal`) : elle remet ces lignes (`SyncApplier.restore`), puis :
  - PA1 : elle garde son paiement, marqué « paiement en double » avec le trop-versé
    (`payroll_periods.double_payment_amount`, seulement les jours payés deux fois), et le signale ;
  - PA2 : elle signale la différence (« 1h00 non payée »).
- **Page Paiement** : le tiroir d'un jour réglé par un paiement en double affiche un bandeau avec le
  trop-versé.
- **Page de synchro** : une phrase claire pour les deux nouveaux refus.

**Fichiers** : `sync_service.dart`, `sync_applier.dart`, `auth_service.dart`
(`PushResult.restore`), `tables/payroll.dart`, `payroll_period.dart`, `payroll_history_page.dart`,
`account_sync_view.dart`.

**Serveur** : `supabase/migrations/20261003000400_paid_days.sql`.

---

## Étape 8 : les employés (E1 à E6)

| Règle | Situation | Ce qui se passe |
|---|---|---|
| E1 | Même CIN ajoutée sur deux tablettes, même établissement | **fusion** : la fiche au plus petit identifiant est gardée, pointages, paiements et mot de passe regroupés ; signalé |
| E1 | Même CIN dans deux établissements | deux personnes, rien n'est regroupé, signalé |
| E2 | Taux ou rôle changé des deux côtés | le dernier gagne, signalé |
| E3 | Archivé d'un côté, modifié de l'autre | réglé à l'étape 4 : reste archivé |
| E4 | Archivé d'un côté, pointe de l'autre | heures gardées (Paiement l'affiche « Retiré » tant qu'il est dû), signalé |
| E5 | Archivé d'un côté, réactivé de l'autre | la dernière décision gagne, signalé |
| E6 | Taux changé pendant un paiement | pas de conflit : le paiement garde le taux de son moment |

**La fusion (E1), champ par champ** : nom, téléphone et email de la fiche gardée ; sa photo, sinon
celle de l'autre ; la date d'embauche la plus ancienne ; le taux de la fiche gardée (signalé s'il
diffère) ; le rôle le plus limité (signalé s'il diffère) ; le mot de passe le plus récent ; actif si
l'une des deux l'est. Deux jours à la même date n'en font qu'un.

**Ce qui a changé.**

- La CIN (colonne `pin`) et l'email sont uniques **par établissement, parmi les fiches vivantes**
  (index partiels `employees_store_pin` et `employees_store_email`). Avant, ils étaient uniques sur
  tout le compte, fiches supprimées comprises, et la deuxième fiche ne pouvait même pas arriver. Le
  formulaire refuse toujours une CIN déjà utilisée n'importe où dans le compte.
- La vérification du PIN au pointage compare la CIN de la personne attendue
  (`EmployeeRepository.sameIdentifier`).
- `SyncApplier` :
  - `_applyEmployee`, `_mergeEmployees` et `_moveEmployeeRows` font la fusion ;
  - `_mergedInto` redirige vers la fiche gardée une ligne qui pointe encore vers la fiche fusionnée ;
  - `_signalArchivedPunches` gère E4.
- `archived_at` rejoint les colonnes surveillées (E5). Le serveur compare maintenant ces valeurs
  dans leur vrai type, pour qu'une même date écrite différemment ne déclenche pas de fausse alerte.

**Fichiers** : `sync_applier.dart`, `sync_service.dart` (`_signalEmployeeOverwrite`),
`sync_indexes.drift`, `tables/employees.dart`, `employee_repository.dart`,
`credential_repository.dart`.

**Serveur** : `supabase/migrations/20261003000500_employees.sql`.

---

## Récapitulatif

### Le schéma local (v21)

| Table | Changement |
|---|---|
| `business_days` | nouvelle table, synchronisée |
| `stores` | `business_day_auto_open_minutes` |
| `attendance_sessions` | `exit_set_by_employee_id` |
| `notifications` | `related_employee_id`, `related_target`, `read_by_manager_at`, `read_by_owner_at` |
| `outbox` | `changed_columns`, `base_values` |
| `employee_credentials` | `failed_attempts`, `locked_until`, `last_login_at` **retirées** |
| `login_states` | nouvelle table, **locale** (jamais synchronisée) |
| `payroll_periods` | `double_payment_amount` |
| `employees` | CIN et email uniques par établissement parmi les fiches vivantes |

### Les migrations serveur, à appliquer dans l'ordre

| Fichier | Contenu |
|---|---|
| `20261003000100_personnel_audit.sql` | colonnes de l'audit, table `business_days`, colonnes des signalements, `pull_changes` |
| `20261003000200_partial_updates.sql` | `apply_change` n'écrit que les colonnes modifiées |
| `20261003000300_credentials.sql` | colonnes de connexion retirées ; réponse `overwrote` |
| `20261003000400_paid_days.sql` | refus `day_already_paid` et `paid_day_frozen`, réponse `restore` |
| `20261003000500_employees.sql` | comparaison typée des valeurs surveillées (retrait) |

⚠️ **Ces migrations n'ont pas été lancées sur un vrai Supabase** : ce PC n'a ni le CLI Supabase ni
ses images Docker. Le comportement a été vérifié avec le faux serveur des tests
(`test/support/fake_account_backend.dart`), qui applique les mêmes règles. Avant la mise en
production, lancer `supabase db reset` puis `supabase test db` (voir `supabase/README.md`).

### Les textes affichés

Tous les signalements sont écrits en français, sans dépendre de la langue chargée (dates `jj/mm/aaaa`
et montants `120,00 €` formatés à la main), pour être identiques sur toutes les tablettes :

| Situation | Titre du signalement |
|---|---|
| P1 | « Double pointage : … » |
| P4 / H1 / H2 | « Deux départs : … » |
| P6 | « Pointage après la fermeture : … » |
| C2 | « Mot de passe changé deux fois : … » |
| PA1 | « Paiement en double : … » |
| PA2 | « Jour déjà payé : … » |
| E1 | « Employé ajouté deux fois : … », « Même CIN dans deux établissements : … » |
| E2 / E5 | « Fiche modifiée sur deux tablettes : … » |
| E4 | « Pointage après le retrait : … » |

---

## Les tests

| Fichier | Ce qu'il vérifie |
|---|---|
| `test/db/sync_personnel_full_test.dart` | **toutes les règles des étapes 1 à 8** avec deux tablettes (33 tests) |
| `test/db/sync_conflicts_test.dart` | les mêmes règles, avec les cas plus fins |
| `test/db/attendance_merge_test.dart` | une journée regroupée : un départ ferme tout, statut, suppression d'un doublon |
| `test/db/signalement_test.dart` | un signalement par situation, lu séparément |
| `test/db/outbox_test.dart` | les colonnes modifiées, les triggers |
| `test/db/migration_test.dart` | les mises à jour vers v21 sans rien perdre |
| `test/attendance_history_page_test.dart` | « Supprimer ce pointage en double » à l'écran |
| `test/payroll_history_page_test.dart` | le bandeau « Paiement en double » |
| `test/notifications_signalement_test.dart` | le filtre « Personnel », l'ouverture de l'historique |

Pour lancer le test complet :

```
flutter test test/db/sync_personnel_full_test.dart
```

Deux échecs dans `test/page_scroll_test.dart` (pages « Fournisseurs » et « Notifications »)
existaient déjà avant ce travail : ils échouent de la même façon sans ces changements.

---

## Limites connues

- **Une ancienne journée restée ouverte** : si la synchro amène une ancienne journée ouverte à
  côté d'une plus récente, la plus récente sert, mais l'ancienne n'est ni fermée ni signalée.
- **Un départ pointé après la fermeture** (P6) : si l'employé est arrivé avant la fermeture et a
  pointé son départ après, sur une tablette hors ligne, ce départ est gardé tel quel. Seules une
  arrivée encore ouverte et une arrivée faite après la fermeture sont corrigées.
- **Qui a supprimé un doublon** : la suppression n'enregistre pas son auteur.
- **Un jour payé seulement sur cette tablette** : si une tablette vient de payer un jour hors ligne
  et reçoit, avant d'envoyer ce paiement, une modification de ce jour faite ailleurs, la
  modification s'applique (elle est arrivée la première au serveur) sans être signalée.
- **Même CIN dans deux établissements** : la connexion par CIN et mot de passe tombe sur une seule
  des deux fiches, jusqu'à ce qu'un gérant corrige la CIN.
- **Une modification faite pendant l'envoi** : elle garde dans sa liste les colonnes déjà envoyées
  et les renvoie avec la suivante. Sans conséquence, sauf si une autre tablette change exactement
  la même colonne entre les deux envois.

---

## Pour un développeur qui reprend

- Après une modification d'une table synchronisée :

  ```
  dart run drift_dev schema dump lib/data/database/app_database.dart lib/data/database/migrations/
  python tool/generate_outbox_triggers.py
  dart run build_runner build --force-jit
  dart run drift_dev analyze
  ```

  **Toujours lancer `drift_dev analyze`.** drift abandonne sans rien dire un trigger dont le SQL
  est refusé (exemple rencontré : le mot réservé `key` doit s'écrire `"key"`). `outbox_test.dart`
  vérifie aussi que chaque table synchronisée a bien ses triggers.
- **Pour ajouter un signalement**, appeler `AccountRepository.signal` avec une clé qui décrit la
  situation de la même façon sur toutes les tablettes. Dans `SyncApplier` (écriture silencieuse),
  l'entourer de `SyncQuiet.loud`, sinon il ne partira pas.
- **Pour surveiller une nouvelle colonne** (signaler quand elle est écrasée), l'ajouter à `WATCHED`
  dans `tool/generate_outbox_triggers.py`, puis traiter son nom dans `SyncRunner._signalOverwrite`.
