# Page Personnel — documentation d'implémentation

Documente le module **Employés** au complet : Personnel (Étape 1), Pointage (Étape 2) et
Historique de pointage (Étape 3), plus le lien Personnel ↔ Équipe ajouté entre les étapes 1 et
2. Suit `.claude/phase_employees.md`. Écrit après coup, pour donner à quiconque reprend ce
code une vue d'ensemble sans avoir à recomposer l'historique des commits.

Les trois étapes du brief sont maintenant construites — il n'y a rien de plus prévu dans ce
module tel que spécifié. §14 liste les pistes explicitement laissées de côté plutôt que
"restant à faire".

---

## 1. Ce qui existe

Un menu déroulant **Employés** dans la barre latérale, avec deux entrées :

- **Personnel** — la liste du personnel d'un établissement : création, modification, retrait
  (suppression douce), fiche détaillée, historique de pointage par personne, et un lien
  optionnel vers un compte d'accès à l'application.
- **Pointage** — un tableau du jour avec un bouton à 4 états par employé (Pointer → Pause →
  Reprendre → Fin de journée), plus un onglet **Historique** listant tous les pointages de
  l'établissement, filtrables par période, statut et employé.

---

## 2. Modèle de données

### `lib/models/employee.dart`

```dart
enum EmployeeType { fixedSalary, student, extra }
enum PayType { monthlySalary, hourlyRate }

class Employee {
  final String id;
  final String storeId;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String cin;            // carte d'identité nationale
  final String? photoAsset;    // simulé, comme Store.imageAsset — pas de vrai upload
  final EmployeeType type;
  final PayType payType;
  final double payRate;        // interprété selon payType : salaire mensuel ou tarif horaire
  final DateTime createdAt;
  final DateTime? archivedAt;  // null = actif. Seule source de vérité pour le retrait.
  final String? teamMemberId;  // lien optionnel vers un TeamMember — voir §8
}
```

**`archivedAt` est la seule source de vérité** pour savoir si quelqu'un est actif — pas de
booléen `isActive` séparé qui pourrait diverger. Même raisonnement que
`PurchaseOrderLine.closedShort`.

### `lib/models/time_entry.dart`

```dart
enum TimeEntryStatus { notClockedIn, onShift, onBreak, clockedOut }

class TimeEntry {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime date;           // le jour concerné, normalisé
  final TimeEntryStatus status;
  final DateTime? clockInAt;
  final DateTime? breakStartAt;
  final DateTime? breakEndAt;
  final DateTime? clockOutAt;
  final bool isLate;             // pause > PointageRules.maxBreakDuration
}
```

Un `TimeEntry` par employé et par jour, créé au premier pointage de la journée — un jour sans
ligne signifie simplement "pas encore pointé", pas besoin d'une ligne vide.

Les deux modèles sont immuables, sans logique, sans `fromJson` — même contrat que tout le
reste du projet.

---

## 3. Dérivations — `core/utils/`

Les modèles restent des données pures ; tout calcul vit à côté, jamais dessus (même principe
que `stock_status.dart` pour `Item`).

- **`employee_status.dart`** — `bool isEmployeeActive(Employee e) => e.archivedAt == null;`
- **`timeclock_status.dart`** :
  - `PointageRules.maxBreakDuration` (30 min) et `.standardWorkDayDuration` (8 h) — constantes
    globales pour l'instant, pas un réglage par établissement (voir §12, point 3).
  - `breakDuration(entry)`, `workedDuration(entry)`, `overtime(entry)` — chacune `null` tant
    que les horodatages nécessaires ne sont pas posés, jamais négative (plancher à zéro).

---

## 4. Données de démonstration

- **`lib/mock_data/mock_employees.dart`** — 6 personnes à la Brasserie du Sablon : un exemple
  de chaque `EmployeeType` et de chaque `PayType`, une personne archivée (Camille Rousseau),
  et **Karim Haddouch**, seul employé relié à un compte d'application. La Taverne Saint-Gilles
  reste vide.
- **`lib/mock_data/mock_time_entries.dart`** — pointages étalés sur 5 jours distincts. Seuls
  les pointages *d'aujourd'hui* sont laissés en cours (`onShift` / `onBreak` pour certains,
  aucune ligne pour Noah et Julien — donc "non pointé" sur le tableau du jour) ; tous les jours
  antérieurs sont terminés. Couvre les deux états démo-critiques : une pause d'Élise qui a
  dépassé le seuil (`isLate: true`) et un service de Karim avec de vraies heures
  supplémentaires.
- **`lib/mock_data/mock_team.dart`** — `user-karim`, ajouté uniquement pour donner un exemple
  concret de lien Personnel ↔ Équipe (§8).

---

## 5. Couche d'écriture

Trois fichiers de mutation, chacun propriétaire d'une seule chose — même principe que
`item_mutations.dart` / `movement_mutations.dart`.

### `lib/mock_data/mutations/employee_mutations.dart`

| Méthode | Rôle |
|---|---|
| `create(...)` | Crée un employé. Refuse un champ vide ou un e-mail déjà utilisé *dans le même établissement*. |
| `update(id, ...)` | Modifie les informations. N'accepte pas `archivedAt` — le retrait passe uniquement par `archive()`. |
| `archive(id)` | Retrait doux : pose `archivedAt`, ne touche jamais `mockTimeEntries`. Refuse un second archivage. Pas de suppression dure. |
| `linkTeamMember(employeeId, teamMemberId)` | Pose le lien vers un compte d'application (§8). |
| `clearTeamMemberLink(teamMemberId)` | Retire ce lien de tout employé qui le portait (§8). |

### `lib/mock_data/mutations/timeclock_mutations.dart` (Étape 2)

**Le seul fichier autorisé à écrire dans `mockTimeEntries`** — même rôle que
`movement_mutations.dart` pour la quantité d'un article. Chaque méthode refuse le mauvais état
de départ plutôt que de le forcer, et prend un paramètre optionnel `now` (comme
`MovementMutations.recordStockIn`'s `occurredAt`) pour que les tests puissent fixer un
horodatage plutôt que d'attendre le temps réel :

| Méthode | Condition refusée | Effet |
|---|---|---|
| `clockIn(employeeId, storeId, {now})` | Un pointage existe déjà aujourd'hui pour cet employé | Crée l'entrée, `status: onShift`, `clockInAt: now` |
| `startBreak(entryId, {now})` | `status != onShift`, **ou une pause a déjà été prise aujourd'hui** | `breakStartAt: now`, `status: onBreak` |
| `endBreak(entryId, {now})` | `status != onBreak` | `breakEndAt: now`, `isLate` posé si la pause dépasse `PointageRules.maxBreakDuration`, retour à `onShift` |
| `clockOut(entryId, {now})` | `status != onShift` | `clockOutAt: now`, `status: clockedOut` |

Le refus d'une seconde pause dans `startBreak` va au-delà de ce que le brief énonçait
littéralement ("refuse sauf si `status == onShift`") : après `endBreak`, le statut redevient
`onShift`, donc un contrôle basé uniquement sur le statut aurait laissé passer une deuxième
pause. La règle "une pause par jour" est donc appliquée à la couche d'écriture, pas seulement
par l'interface qui cache le bouton.

### `lib/mock_data/mutations/account_mutations.dart` (modifié à l'étape 1)

`removeMember(id)` appelle `EmployeeMutations.clearTeamMemberLink(id)` après avoir retiré le
membre — pour qu'un employé ne pointe jamais vers un compte qui n'existe plus.

### `mock_write.dart`

`mockEmployees` et `mockTimeEntries` sont inclus dans `MockWrite.captureSeed()` / `reset()` —
sans quoi **Réinitialiser la démonstration** cesserait silencieusement de restaurer le
personnel et les pointages après une première utilisation.

---

## 6. Routes et navigation

### `lib/app/routes.dart`

```
/store/:storeId/employees                                Personnel (liste)
/store/:storeId/employees/new                              Ajouter un employé
/store/:storeId/employees/:employeeId                       Fiche employé
/store/:storeId/employees/:employeeId/edit                  Modifier
/store/:storeId/employees/:employeeId/link-team              Donner un accès à l'application
/store/:storeId/employees/timeclock                         Pointage (tableau du jour + onglet Historique)
```

`new` est déclaré avant `:employeeId` pour la même raison d'ordre go_router que les commandes
déclarent `new` avant `:orderId`.

### Barre latérale — `lib/shared/widgets/app_sidebar.dart`

Une entrée **Employés** ouvre un menu (`showMenu`, ancré sur l'icône de la ligne) avec
**deux items : Personnel et Pointage**, plutôt que de naviguer directement ou de faire
grandir le rail avec un accordéon — `router_test.dart` avait déjà attrapé une régression de
hauteur sur petite tablette par le passé, donc le rail garde un nombre d'entrées fixe (11).

`_Destination` distingue deux formes : une destination qui navigue directement
(`pathBuilder`) ou une qui ouvre un flyout (`flyout`), jamais les deux — vérifié par un
`assert`.

### Onglets *à l'intérieur* de la page Pointage

`timeclock_board_page.dart` a ses propres onglets **Aujourd'hui / Historique**, via
`SectionTabs` avec un `onSelected` qui change juste ce qui est affiché — **pas de route
séparée**, exactement comme les onglets Lignes/Réceptions de `order_detail_page.dart`. Le
choix du brief (assomption 5) : deux vues d'un même écran, pas deux écrans.

---

## 7. Pointage — le tableau du jour (Étape 2)

### `lib/shared/widgets/time_entry_status_badge.dart`

`TimeEntryStatusBadge` — même construction que `StockStatusBadge` : couleur + icône
distincte + texte, jamais la couleur seule (règle vérifiée par `ux_audit.py`). Réutilise des
teintes existantes plutôt que d'en inventer : `onShift` → vert (`AppColors.inStock`),
`onBreak` → ambre (`AppColors.lowStock`), `clockedOut` → gris (`AppColors.offline`),
`notClockedIn` → neutre. C'est aussi ce fichier qui porte désormais
`timeEntryStatusLabel(l10n, status)`, partagé par tous les écrans qui affichent un statut de
pointage.

### `lib/features/employees/presentation/pages/timeclock_board_page.dart`

- En-tête : date du jour + **horloge en direct**, isolée dans son propre widget avec son
  propre `Timer.periodic` (annulé dans `dispose`), pour que le tic de chaque seconde ne
  redessine pas la liste des employés en dessous.
- Onglet **Aujourd'hui** : une carte par employé **actif** (les employés archivés n'ont rien à
  pointer), triées "non pointé" en premier pour qu'on retrouve vite sa propre carte en début
  de service. Chaque carte affiche le badge de statut et le bouton pertinent :

  | Statut du jour | Bouton | Appelle | Nouveau statut |
  |---|---|---|---|
  | (aucune entrée) | **Pointer** | `TimeclockMutations.clockIn` | En service |
  | En service, pause pas encore prise | **Pause** | `TimeclockMutations.startBreak` | En pause |
  | En pause | **Reprendre** | `TimeclockMutations.endBreak` | En service |
  | En service, pause déjà prise | **Fin de journée** | `TimeclockMutations.clockOut` | Terminé |

  Une fois "Terminé", la carte devient un résumé en lecture seule (durée travaillée, heures
  supplémentaires si positives, marque "Retard pause" si `isLate`) — plus de bouton pour le
  reste de la journée.
- Snackbar de succès à chaque pointage, comme toute autre écriture de l'application.

**Écart assumé** : l'onglet Historique n'a volontairement **pas** été construit en même temps
que le tableau du jour — son contenu dépendait de l'Étape 3, et un onglet qui ne mène nulle
part aurait été pire que pas d'onglet du tout. La page a été livrée en vue unique, puis
enveloppée dans `SectionTabs` à l'Étape 3.

---

## 8. Historique de pointage (Étape 3)

### `MockQueries.timeEntriesForStore` (`lib/mock_data/mock_queries.dart`)

```dart
static List<TimeEntry> timeEntriesForStore(
  String storeId, {
  int? withinDays,        // null = pas de coupure ("Tout")
  TimeEntryStatus? status,
  String? employeeQuery,
})
```

Combine les trois filtres avec un ET logique, résout le nom de chaque employé via
`employeeById` (jamais dupliqué dans l'UI), trie du jour le plus récent au plus ancien — même
convention que `timeEntriesForEmployee`. La recherche par nom réutilise `_normalise`
(le même helper que pour les catégories/unités/e-mails), donc insensible à la casse et aux
espaces superflus.

### L'onglet Historique

Construit sur le modèle de `lib/features/stock_movement/presentation/pages/
stock_history_page.dart` (le journal de mouvements de stock) plutôt que sur une grille
`DataTableWrapper` — c'est le précédent le plus proche déjà existant dans le code : un journal
filtrable avec plusieurs `FilterPill` indépendants, une ligne de compte de résultats, deux
états vides distincts (rien du tout vs. aucun résultat pour les filtres, avec une action
"effacer les filtres" sur le second), et une liste de lignes plutôt qu'un tableau dense.

- **Période** — une énumération locale à 4 valeurs (7 / 30 / 90 jours / tout), délibérément
  dupliquée depuis l'équivalent de `stock_history_page.dart` plutôt qu'importée : importer à
  travers les dossiers de fonctionnalités (`employees/` ← `stock_movement/`) aurait été le
  seul cas de ce genre dans tout le projet.
- **Statut** — `TimeEntryStatus?`, avec une option "Tous".
- **Employé** — un `SearchField` texte libre (comme la recherche de `employees_list_page.dart`),
  pas une liste déroulante de noms — le nombre d'employés peut grandir, contrairement à la
  courte liste d'utilisateurs du journal de stock.
- Chaque ligne : date, **nom de l'employé** (nouveau — l'historique couvre tout
  l'établissement, pas une seule personne), horaires (entrée / pause / sortie), durée
  travaillée, badge de statut, icône de retard si `isLate`.

`lib/features/employees/presentation/widgets/time_entry_history_list.dart` a été étendu plutôt
que dupliqué : le rendu d'une ligne (`_TimeEntryRow`) est devenu le widget public
`TimeEntryRow`, avec trois paramètres optionnels — `employeeName` (ajoute la colonne nom),
`useStatusBadge` (badge complet plutôt que la pastille neutre — la fiche d'un seul employé n'a
rien d'urgent à signaler, l'historique global si), `asCard` (ligne présentée comme une carte
séparée, plutôt qu'une ligne bordée dans une carte commune). La fiche employé
(`EmployeeDetailPage`) n'a eu besoin d'aucune modification : elle continue d'utiliser
`TimeEntryHistoryList` telle quelle.

---

## 9. Lien Personnel ↔ Équipe

### Pourquoi ne pas fusionner `Employee` et `TeamMember`

`TeamMember` répond à « qui a le droit d'utiliser l'application et avec quels droits »
(rôle owner/manager/staff, accès multi-établissements via `storeIds`). `Employee` répond à
« qui travaille ici et comment il est payé » (type, salaire ou tarif horaire, CIN, un seul
établissement). Un plongeur peut pointer sans jamais ouvrir l'application ; un gérant peut
couvrir plusieurs établissements sans que ça change son statut d'employé. Fusionner les deux
aurait rendu fragile le cas où quelqu'un perd l'un sans perdre l'autre.

### La solution retenue : un lien optionnel

`Employee.teamMemberId` (nullable) pointe vers un `TeamMember`. Le lien est porté par
`Employee` — comme `StockMovement` pointe vers la commande dont il découle plutôt que
l'inverse : l'enregistrement secondaire nomme le principal.

### Le parcours

1. Sur la fiche employé (**"Accès à l'application"**) : un bouton si aucun lien, une ligne
   cliquable montrant le rôle sinon.
2. Le bouton ouvre **`LinkTeamAccessPage`** (`.../employees/:employeeId/link-team`) — nom et
   e-mail affichés en lecture seule, seuls le rôle et les établissements sont à choisir.
3. À la validation : `AccountMutations.invite(...)` crée le `TeamMember` (ou renvoie `null` et
   affiche un bandeau d'erreur si l'e-mail est déjà pris par un autre compte non lié), puis
   `EmployeeMutations.linkTeamMember(...)` pose le lien — deux écritures séparées, une par
   fichier de mutation.
4. Si le compte est retiré plus tard via l'écran Équipe, le lien est automatiquement effacé
   côté employé (§5) — la fiche retombe sur l'état « aucun accès ».

**Exemple dans les données de démonstration** : Karim Haddouch est relié au compte
`user-karim` (rôle *Employé*).

---

## 10. Écrans

| Fichier | Rôle |
|---|---|
| `employees_list_page.dart` | Racine "Personnel", atteinte depuis le flyout. Recherche par nom, bascule "Afficher les personnels retirés". |
| `add_edit_employee_page.dart` | Un seul formulaire pour créer et modifier. Libellé du tarif réactif au type de rémunération. Photo simulée. |
| `employee_detail_page.dart` | Coordonnées, emploi, accès à l'application (§9), historique de pointage (`TimeEntryHistoryList`). |
| `link_team_access_page.dart` | Décrit au §9. |
| `timeclock_board_page.dart` | Racine "Pointage", atteinte depuis le flyout. Onglets Aujourd'hui (§7) / Historique (§8). |
| `widgets/time_entry_history_list.dart` | `TimeEntryHistoryList` (une personne) et le `TimeEntryRow` public qu'elle et l'onglet Historique partagent tous les deux. |

---

## 11. Traductions

Toutes les chaînes passent par `AppLocalizations` (`lib/l10n/app_fr.arb`, régénéré via
`flutter gen-l10n`). Chaque étape a réutilisé les clés existantes plutôt que de dupliquer le
texte quand c'était possible — les libellés de statut de pointage
(`timeEntryStatus*`), les libellés de période (`periodLast7Days`/`30`/`90`/`All`, déjà utilisés
par le journal de mouvements de stock) et les états vides génériques
(`emptyStateNoResultsTitle`/`Body`) sont partagés plutôt que redéfinis à chaque étape.

---

## 12. Tests

- **`test/employees_test.dart`** — création, modification, archivage, et le groupe
  **"linking an application account"** pour le lien Personnel ↔ Équipe.
- **`test/account_test.dart`** — retirer un compte efface bien le lien de l'employé concerné.
- **`test/timeclock_test.dart`** — la machine à états du pointage (double pointage refusé,
  pause avant pointage refusée, sortie pendant une pause refusée, deuxième pause le même jour
  refusée, seuil de retard des deux côtés, heures supplémentaires), plus le groupe
  **"timeEntriesForStore (Historique tab)"** : filtre de période (coupure exclut/inclut
  correctement, `null` retourne tout), filtre de statut seul, filtre de nom seul
  (insensible à la casse, correspondance partielle), les trois combinés, et l'ordre de tri.
- **`test/navigation_test.dart`** / **`test/router_test.dart`** — étendus pour le flyout à
  deux items et la route Pointage, à travers les trois tailles de tablette testées.
- **`test/mock_write_test.dart`** — `mockEmployees` et `mockTimeEntries` couverts par le test
  de restauration intégrale.

---

## 13. État de la qualité

Au moment de la rédaction de ce document, module complet (étapes 1 à 3) :

- `flutter analyze` — aucun problème.
- `flutter test` — **397 tests passent** (0 échec).
- `python tool/ux_audit.py` — **0 violation** sur les douze contrôles.

---

## 14. Hypothèses assumées, et pistes explicitement laissées de côté

Repris de `.claude/phase_employees.md` et des choix faits pendant l'implémentation :

1. **Photo** — champ simulé, aucun vrai sélecteur de fichier.
2. **Type d'employé** — énumération fermée à trois valeurs, même philosophie que `TeamRole`.
3. **Seuils de pointage** (`PointageRules`) — constantes globales, pas un réglage par
   établissement. `stalePartialOrderDays` (paramètres du magasin) est le précédent si on veut
   les promouvoir en réglage plus tard.
4. **Lien Personnel ↔ Équipe** — lien optionnel et manuel plutôt qu'une fusion des deux
   modèles (§9).
5. **Une seule pause par jour** — imposée à la couche d'écriture (`timeclock_mutations.dart`),
   pas seulement par l'interface.
6. **Historique de pointage filtré par fenêtre glissante** (`withinDays`, comme le journal de
   mouvements de stock) plutôt que par sélection libre d'une plage de dates — cohérent avec le
   seul précédent de filtre de période déjà présent dans l'application.
7. **`EmployeeDetailPage` n'a pas été retouché** pour passer par
   `MockQueries.timeEntriesForStore` — il continue d'utiliser `timeEntriesForEmployee`, qui
   fonctionne déjà et reste testé séparément. Un changement possible plus tard, pas nécessaire.

Rien de tout cela n'est bloquant ; ce sont des décisions à confirmer ou à faire évoluer avec
le client plutôt que des manques.
