# Phase 6 — Auth + permissions

La dernière phase du module : un login **CIN + PIN** (faux), une **session** réelle avec
déconnexion, un **verrou** après 3 codes faux, une **garde de routage**, et une table de
permissions `can(role, capability)` qui pilote le menu, les routes et les boutons d'action.
Contrat : `.claude/phase_gestion_employee.md` §Phase 6.

Fin de phase : `flutter analyze` propre, **438 tests passent**, `python tool/ux_audit.py`
→ **0 violation**.

> **Toujours faux, délibérément.** Pas de backend, pas de vrai hachage, pas de réseau.
> `pinHash` = `'pin:<pin>'`. Ce qui est *réel* : la machine à états (tentatives, verrou,
> remise à zéro au succès), le refus des `staff`, et le gating par rôle.

---

## 1. Modèle — `lib/models/employee_credential.dart`

```dart
class EmployeeCredential {
  final String id;
  final String employeeId;
  final String pinHash;          // jamais le PIN en clair (faux hash)
  final int failedAttempts;      // codes faux consécutifs depuis le dernier succès
  final DateTime? lockedUntil;   // posé au seuil ; refuse même le bon PIN jusque-là
  final DateTime? lastLoginAt;
}
```

Aggregate à part (pas un champ sur `Employee`) — un changement de taux et un compteur
d'échecs n'ont rien à voir. Barrel `models.dart`.

### Dérivations — `lib/core/utils/credential_status.dart`

- `AuthRules` : `pinLength = 4`, `maxFailedAttempts = 3`, `lockoutDuration = 5 min`.
- `fakePinHash(pin)`, `pinMatches(credential, pin)`, `isValidPin(pin)` (4 chiffres),
  `isLocked(credential, {now})`.

### Permissions — `lib/core/utils/permissions.dart`

```dart
enum Capability {
  manageEmployees, viewTimeclock, viewAttendanceHistory,
  managePayroll, editStoreSettings, createStore,
}
bool can(EmployeeRole role, Capability c);
```

| Rôle | Capacités |
|---|---|
| **owner** | toutes |
| **manager** | `viewTimeclock`, `viewAttendanceHistory` |
| **staff** | aucune (et ne peut pas se connecter) |

Fonction pure — les call sites passent `mockCurrentEmployee.role`.

---

## 2. Session — `lib/mock_data/mock_session.dart`

`MockSession` : `current` (`Employee?`), `signIn` / `signOut` / `isSignedIn` +
`resetToDefault` (`@visibleForTesting`). **Valeur par défaut = le propriétaire (Marc)** —
pas pour l'app (que `main()` déconnecte au démarrage) mais pour les tests widget qui montent
l'arbre directement : ils obtiennent une session owner sans étape de login, donc
`router_test` / `navigation_test` / `widget_test` sont **inchangés**.

`mockCurrentEmployee` reste un getter du même nom → `MockSession.current ?? _defaultOwner`.
Aucun call site à renommer.

`lib/main.dart` : `MockSession.signOut()` juste après `MockWrite.captureSeed()`.

---

## 3. Données + mutations

- **`lib/mock_data/mock_credentials.dart`** — une `EmployeeCredential` par employé,
  **PIN `1234` pour tous** (prototype ; le formulaire de login pré-remplit le CIN de Marc +
  `1234`). Personne ne démarre verrouillé.
- **`lib/mock_data/mutations/credential_mutations.dart`** — seul écrivain de
  `mockCredentials` :
  - `setPin(employeeId, pin)` — crée/remplace, remet compteur + verrou à zéro. `null` si PIN
    invalide ou employé inconnu.
  - `recordFailedAttempt(employeeId, {now})` — incrémente ; pose `lockedUntil` au seuil ;
    renvoie « a verrouillé ».
  - `recordSuccessfulLogin(employeeId, {now})` — compteur 0, verrou null, `lastLoginAt`.
  - `unlock(employeeId)` — lève le verrou tôt.
  - `authenticate(cin, pin, {now}) → LoginAttempt(outcome, employee?)` — compose les
    primitives. `outcome ∈ {success, unknownCin, wrongPin, locked, noAppAccess}`. **Ne touche
    pas `MockSession`** — la page appelle `signIn` sur `success`.
- **`MockWrite`** — `mockCredentials` ajouté au snapshot `_Seed`. La **session** n'y est
  **pas** (« Réinitialiser la démonstration » ne doit pas déconnecter) — les tests la
  remettent via `restoreMockData()`.
- **`MockQueries.credentialForEmployee(employeeId)`**.

---

## 4. Garde de routage — `lib/app/router.dart`

`redirect: _guard` :

1. pas de session → tout sauf `{login, forgotPassword, onboarding}` renvoie vers `/login` ;
2. session `staff` (jamais émise par l'app) → `/login` ;
3. session sur une route d'auth → `/stores` ;
4. capacité manquante pour la section (`_capabilityFor`) → dashboard du magasin (ou `/stores`).

`_capabilityFor` : `/employees/timeclock`→`viewTimeclock`,
`/employees/attendance-history`→`viewAttendanceHistory`, `/employees/payroll`→`managePayroll`,
sinon `/employees…`→`manageEmployees`, `/stores/add`→`createStore`.
**`/settings/store` n'est pas gardée** — sinon un manager tombe sur un cul-de-sac depuis le
rail ; seul le bouton « Enregistrer » y est désactivé.

---

## 5. Écran de login — `lib/features/auth/presentation/pages/login_page.dart`

E-mail / mot de passe → **CIN** + **code PIN** (4 chiffres, masqué). `_signIn()` appelle
`CredentialMutations.authenticate` puis :

| `outcome` | effet |
|---|---|
| `success` | `MockSession.signIn` → `/stores` |
| `unknownCin` / `wrongPin` | encart d'erreur « CIN ou code PIN incorrect » |
| `locked` | encart « Compte verrouillé après plusieurs tentatives » |
| `noAppAccess` | encart « Ce compte n'a pas accès à l'application » |

Lien « Code oublié ? » inchangé (route `forgotPassword`). Note de démo conservée.
Déconnexion : `MockSession.signOut()` ajouté avant `goSection(Routes.login)` dans
`app_top_bar.dart` et `store_selector_page.dart`.

---

## 6. Gating de l'UI

- **`app_sidebar.dart`** — `_ChildDestination` gagne un champ `Capability`. Les enfants de
  « Gestion Employée » sont filtrés par `can(role, child.capability)` ; si aucun ne passe, la
  ligne parente disparaît. Manager → 2 enfants (Tableau de pointage, Historique pointage) ;
  owner → 4.
- **`store_settings_page.dart`** — bouton « Enregistrer » désactivé + encart lecture seule si
  `!can(role, editStoreSettings)`. Route non gardée (voir §4).
- **`store_selector_page.dart`** — bouton « Ajouter un établissement » masqué si
  `!can(role, createStore)` (route gardée en plus).
- **Roster** (`employees_list_page`, `employee_detail_page`) — **rien** : la route
  `/employees…` est gardée à `manageEmployees` (owner), les boutons ne sont jamais rendus
  pour un manager. Idem « Payer ».

---

## 7. Section identifiants — `add_edit_employee_page.dart`

Nouvelle section « Identifiants » : **PIN** + **Confirmer le code** (4 chiffres, masqués).
- **Création** : PIN requis (`_canSubmit` inclut `_pinValid`) → au succès
  `CredentialMutations.setPin(created.id, pin)`.
- **Édition** : facultatif — « laisser vide pour conserver le code actuel » ; `setPin` seulement
  si les champs sont remplis.
- Erreur « les deux codes ne correspondent pas » sous le champ de confirmation.

---

## 8. Décisions

- **Session par défaut = owner** (déconnectée par `main()`) plutôt que `null` — évite de
  toucher aux suites de routage/navigation existantes.
- **`staff` refusé au login** (message), pas d'écran « accès réservé » dédié.
- **Réglages établissement** : route ouverte, bouton gardé — pas de cul-de-sac dans le rail.
- **Pas** de page « Rôles et permissions » : la table `can()` vit seulement dans
  `permissions.dart`.
- Verrou : **3 tentatives / 5 min**.

---

## 9. Tests

- **`test/auth_test.dart`** — `authenticate` (succès / CIN inconnu / PIN faux) ; verrou au
  3ᵉ échec ; verrouillé refuse le bon PIN puis l'accepte après expiration + remise à zéro ;
  `staff` → `noAppAccess` compteurs intacts ; `setPin` (remplace, rejette invalide) ;
  `unlock` ; `MockWrite.reset()` restaure les credentials.
- **`test/permissions_test.dart`** — table `can()` complète ; garde de routage (déconnecté →
  `/login` ; manager bloqué sur `/employees` et `/payroll`, autorisé sur `/timeclock` et
  `/attendance-history` ; manager bloqué sur `/stores/add`) ; rail : 4 enfants owner, 2 manager.
- `test/support/mock_reset.dart` : `restoreMockData()` remet aussi `MockSession`.
- `test/mock_write_test.dart` / `test/mock_data_test.dart` : `mockCredentials` ajouté au
  snapshot ; intégrité référentielle des credentials.

---

## 10. Ce qui reste faux / hors périmètre

- Hachage bidon, aucun chiffrement, aucun réseau.
- « Rester connecté » n'est pas persisté (pas de stockage).
- Pas de flux réel « mot de passe / code oublié » (l'écran envoie toujours rien).
- Enforcement des permissions au niveau **mutation** non ajouté (un appel direct à
  `EmployeeMutations.archive` ne vérifie pas le rôle) — le gating est au niveau route + UI,
  suffisant pour un prototype ; à durcir avec le vrai backend.
