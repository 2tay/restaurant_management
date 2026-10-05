# Synchronisation du personnel : scénarios à tester avec deux tablettes

Ce fichier sert à vérifier **en conditions réelles** les règles de conflit de
`SYNC_PERSONNEL_PLAN.md`, avec deux vraies tablettes. Chaque scénario dit quoi faire sur chaque
tablette, dans quel ordre, et ce qu'on doit voir à la fin **sur les deux**.

**Périmètre : uniquement le personnel** : la connexion, les employés, le tableau de pointage,
l'historique de pointage et le paiement.

---

## 0. Avant de commencer

### Prérequis

- [ ] Les migrations Supabase sont appliquées sur le serveur, **jusqu'à
      `20261005000100_no_passwords.sql` comprise**. Elles n'ont jamais été lancées sur un vrai
      serveur : commencer par `supabase db reset` puis `supabase test db` sur un serveur de test.
- [ ] **La même version de l'application** est installée sur les deux tablettes (schéma v22).
- [ ] Les deux tablettes sont reliées au **même restaurant** : le propriétaire crée le restaurant
      sur la tablette **A**, puis la tablette **B** le rejoint avec le code.
- [ ] Les deux tablettes sont **à la même heure** (heure automatique activée). Plusieurs règles
      comparent des heures.

### Les données de test

Sur la tablette **A**, en ligne, créer dans le même établissement :

| Nom | Rôle | E-mail | Numéro PIN | Taux |
|---|---|---|---|---|
| Léa Test | Gérant | `lea@test.be` | `11.11.11-111.11` | 20 € |
| Karim Test | Employé | `karim@test.be` | `22.22.22-222.22` | 15 € |
| Sara Test | Employé | `sara@test.be` | `33.33.33-333.33` | 15 € |

Synchroniser A, puis B. Vérifier que **B voit les trois fiches**.

### Les gestes utilisés partout

| Geste | Comment |
|---|---|
| **Couper le réseau** | mode avion, ou Wi-Fi coupé, sur la tablette indiquée |
| **Remettre le réseau** | réactiver le Wi-Fi |
| **Synchroniser** | Paramètres → État de la synchronisation → « Synchroniser maintenant » |
| **Ronde complète** | remettre le réseau sur les deux tablettes, puis synchroniser **A, puis B, puis A** (et encore B si un résultat diffère) |
| **Voir les signalements** | la cloche → filtre « Personnel » |

> **L'ordre de synchronisation compte.** Quand une règle dit « le dernier gagne » ou « le premier
> arrivé au serveur garde », c'est l'ordre dans lequel les tablettes **envoient** au serveur.
> Respecter l'ordre indiqué dans chaque scénario.

### À vérifier à la fin de chaque scénario

1. **A et B affichent exactement la même chose** (heures, statuts, montants, fiches).
2. Le **signalement attendu** apparaît **une seule fois**, sur les deux tablettes.
3. Aucune heure travaillée ni aucun paiement n'a disparu (sauf si le scénario le prévoit).
4. Rien n'est en erreur sur la page de synchronisation (sauf un refus prévu par le scénario).

Pour chaque scénario, cocher **OK**, ou noter **KO** avec ce qu'on a vu, sur quelle tablette, et
une capture d'écran.

---

## 1. Connexion (e-mail + numéro PIN)

### L1 — Un gérant créé sur A se connecte sur B
- **A (en ligne)** : créer « Léa Test » (déjà fait dans la préparation).
- Synchroniser A, puis B.
- **B** : se déconnecter, puis se connecter avec `lea@test.be` et `11.11.11-111.11`.
- **Attendu** : la connexion réussit sur B et ouvre le tableau de bord de l'établissement.
- [ ] OK

### L2 — Mauvais PIN, puis pas de blocage
- **B** : se connecter avec `lea@test.be` et un PIN faux, **5 fois de suite**.
- **Attendu** : « E-mail ou numéro PIN incorrect. » à chaque fois. Au 6e essai avec le bon PIN, la
  connexion réussit (il n'y a plus de blocage).
- [ ] OK

### L3 — Un employé n'a pas accès à l'application
- **B** : se connecter avec `karim@test.be` et `22.22.22-222.22`.
- **Attendu** : refus, avec un message qui dit qu'il n'a pas accès à l'application.
- [ ] OK

### L4 — Le rôle changé sur A est appliqué sur B
- **A** : modifier Karim → « Tarif et rôle » → Gérant → Enregistrer. Synchroniser A, puis B.
- **B** : se connecter avec `karim@test.be` et son PIN.
- **Attendu** : la connexion réussit. *Remettre ensuite Karim en Employé et synchroniser.*
- [ ] OK

### L5 — Un employé retiré ne peut plus se connecter
- **A** : retirer Léa (Personnel → sa fiche → Retirer). Synchroniser A, puis B.
- **B** : se connecter avec `lea@test.be` et son PIN.
- **Attendu** : refus « Ce compte a été retiré de l'équipe… ». *Restaurer Léa ensuite et
  synchroniser.*
- [ ] OK

---

## 2. Tableau de pointage

### P1 — Arrivée pointée sur les deux tablettes
- **Couper le réseau** sur A et B.
- **A** : Karim → « Pointer » à 09:00 (confirmer avec son PIN).
- **B** : Karim → « Pointer » vers 09:03.
- **Ronde complète.**
- **Attendu sur A et B** :
  - une seule journée pour Karim, avec **deux arrivées** (09:00 et 09:03) ;
  - un signalement « Double pointage : Karim Test » ;
  - dans Historique pointage → la journée de Karim : un bloc « Pointage en double » avec
    « Supprimer ce pointage en double ».
- **Suite** : sur A, « Fin de journée » pour Karim. Ronde complète.
  **Attendu** : **les deux arrivées** sont fermées à la même heure, et le statut est « Terminé » sur
  A et B.
- **Suite 2** : sur B, supprimer le pointage en double (confirmer). Ronde complète.
  **Attendu** : il ne reste qu'une arrivée, sur les deux tablettes.
- [ ] OK

### P3 — Pause sur une tablette, départ sur l'autre
- Karim est « En service » sur les deux tablettes (pointer en ligne, puis synchroniser).
- **Couper le réseau** sur A et B.
- **A** : Karim → « Pause » à 12:00.
- **B** : Karim → « Fin de journée » à 12:30.
- **Ronde complète.**
- **Attendu sur A et B** : Karim est « Terminé » (et non « En pause »). La pause se termine au
  départ (12:30) dans le calcul des heures.
- [ ] OK

### P4 — Deux départs différents pour la même arrivée
- Karim est « En service » sur les deux tablettes.
- **Couper le réseau** sur A et B.
- **A** : Karim → « Fin de journée » à 17:00.
- **B** : Karim → « Fin de journée » à 17:30.
- **Ronde complète.**
- **Attendu sur A et B** : le départ gardé est **17:00** (le plus tôt), et un signalement
  « Deux départs : Karim Test » apparaît, car l'écart dépasse 15 minutes.
- **Variante sans signalement** : refaire avec 17:00 et 17:10. **Attendu** : 17:00 gardé, **aucun**
  signalement (écart ≤ 15 min).
- [ ] OK  - [ ] Variante OK

### P5 — Journée de service ouverte sur les deux tablettes
- La journée du jour n'est pas encore ouverte. **Couper le réseau** sur A et B.
- **A** : Karim → « Pointer » (cela ouvre la journée sur A).
- **B** : Sara → « Pointer » (cela ouvre « la » journée sur B).
- **Ronde complète.**
- **Attendu sur A et B** : **une seule** journée de service ouverte. Karim et Sara sont tous les
  deux « En service ». Aucun pointage n'a disparu.
- [ ] OK

### P6-a — Journée fermée sur A pendant qu'un employé est encore en service sur B
- Journée ouverte et synchronisée. **Couper le réseau** sur B seulement.
- **B** : Sara → « Pointer » à 16:00 (A ne le sait pas).
- **A** (en ligne) : terminer les journées de ceux qu'A voit en service, puis « Fermer la journée »
  à 17:30.
- **Ronde complète.**
- **Attendu sur A et B** :
  - la journée reste **fermée** ;
  - la journée de Sara a un départ à **17:30** (l'heure de fermeture), et elle est « Terminé » ;
  - un signalement « Pointage après la fermeture : Sara Test », qui dit « son départ est mis à
    17:30 ».
- **Variante** : Sara est en **pause** sur B au moment de la fermeture. **Attendu** : la pause
  aussi s'arrête à 17:30.
- [ ] OK  - [ ] Variante OK

### P6-b — Arrivée pointée sur B **après** la fermeture faite sur A
- Journée ouverte et synchronisée. **Couper le réseau** sur B.
- **A** (en ligne) : « Fermer la journée » à 17:30.
- **B** (qui croit encore la journée ouverte) : Karim → « Pointer » à 17:45.
- **Ronde complète.**
- **Attendu sur A et B** :
  - la journée reste fermée ;
  - le pointage de 17:45 a **disparu** (si Karim n'avait rien d'autre ce jour-là, sa journée a
    disparu aussi) ;
  - un signalement « Pointage après la fermeture : Karim Test », qui dit « l'arrivée de 17:45
    n'est pas comptée ».
- [ ] OK

### P6-c — Limite connue (à constater, pas une erreur)
- Karim est en service, synchronisé. **Couper le réseau** sur B.
- **A** : « Fermer la journée » à 17:30, en donnant à Karim un départ à 17:30.
- **B** : Karim → « Fin de journée » à 18:00.
- **Ronde complète.**
- **Attendu** : le départ le plus tôt (17:30) est gardé (règle P4), avec un signalement « Deux
  départs ». Noter ce qu'on observe.
- [ ] Observé :

---

## 3. Historique de pointage

### H1 — Deux gérants corrigent le même départ oublié
- Une journée de Karim est restée sans départ (par exemple hier, arrivée à 09:00), synchronisée.
- **Couper le réseau** sur A et B.
- **A** (connecté en Léa) : Historique pointage → la journée → « Corriger la sortie » → 17:00.
- **B** (connecté en propriétaire) : même journée → « Corriger la sortie » → 18:00.
- **Ronde complète.**
- **Attendu sur A et B** : la sortie est **17:00**, enregistrée au nom de la personne qui l'a
  saisie. Le signalement « Deux départs : Karim Test » apparaît **toujours**, quel que soit
  l'écart, car c'est une correction.
- [ ] OK

### H2 — La correction d'un gérant contre le départ pointé par l'employé
- Karim est en service, synchronisé. **Couper le réseau** sur A et B.
- **A** : Karim → « Fin de journée » à 17:40.
- **B** : un gérant corrige la sortie de cette journée à 17:20 (si la correction n'est pas proposée
  pour le jour en cours, faire ce scénario sur une journée restée ouverte la veille).
- **Ronde complète.**
- **Attendu sur A et B** : 17:20 (le plus tôt) est gardé, avec le signalement « Deux départs ».
- [ ] OK

### H3 — Supprimer un pointage en double sur un jour déjà payé
- Reprendre une journée avec deux arrivées (P1), puis la **payer** (voir PA). Synchroniser.
- **A** : Historique pointage → cette journée → « Supprimer ce pointage en double ».
- **Attendu** : la suppression n'est pas possible (le bouton n'est pas proposé, ou elle est refusée
  avec « la journée a changé entre-temps (payée… ») ; rien ne change.
- [ ] OK

---

## 4. Paiement

### PA1 — Le même employé payé sur les deux tablettes
- Karim a 2 jours terminés et non payés, synchronisés sur A et B.
- **Couper le réseau** sur A et B.
- **A** : Historique de paiement → Karim → « Payer » ces 2 jours (confirmer avec le PIN).
- **B** : « Payer » les mêmes 2 jours.
- Remettre le réseau. **Synchroniser A en premier**, puis B, puis A.
- **Attendu sur A et B** :
  - les jours sont réglés par **le paiement de A** (le premier arrivé au serveur) ;
  - le paiement de B **existe toujours**, marqué « Paiement en double », avec le **trop-versé**
    (le montant des jours payés deux fois) ;
  - un signalement « Paiement en double : Karim Test » ;
  - sur la page de synchronisation de B : un refus expliqué en clair (jour déjà payé), sans
    erreur bloquante.
- **Variante** : B paie **1 seul** des 2 jours. **Attendu** : le trop-versé ne compte que ce jour-là.
- [ ] OK  - [ ] Variante OK

### PA2 — Un changement arrive sur un jour déjà payé
- Karim a une journée terminée (09:00 → 17:00), non payée, synchronisée.
- **Couper le réseau** sur A.
- **B** (en ligne) : payer cette journée. Synchroniser B.
- **A** (hors ligne, ne sait pas qu'elle est payée) : corriger cette journée (par exemple, départ à
  18:00 au lieu de 17:00, ou ajouter une pause).
- Remettre le réseau sur A. Synchroniser A, puis B.
- **Attendu sur A et B** :
  - la journée garde **17:00** ; le montant payé ne change pas ;
  - sur A, la modification est **annulée** et la journée revient comme sur le serveur ;
  - un signalement « Jour déjà payé : Karim Test », avec la différence (« 1h00 non payée ») ;
  - la page de synchronisation de A explique le refus (jour payé, figé).
- [ ] OK

### E6 — Le taux change pendant un paiement
- **Couper le réseau** sur A et B.
- **A** : changer le taux de Karim de 15 € à 18 €.
- **B** : payer des jours de Karim (au taux de 15 €).
- **Ronde complète.**
- **Attendu** : le paiement fait sur B reste **à 15 €** ; la fiche de Karim est à **18 €** ; pas de
  conflit.
- [ ] OK

---

## 5. Employés

### E1-a — La même CIN ajoutée sur les deux tablettes, même établissement
- **Couper le réseau** sur A et B.
- **A** : ajouter « Nora Test », PIN `44.44.44-444.44`, e-mail `nora@test.be`, téléphone
  `0470 11 11 11`, taux 15 €, Employé. La faire **pointer**.
- **B** : ajouter « Nora Test », **même PIN**, e-mail `nora2@test.be`, téléphone `0470 22 22 22`,
  taux 16 €, Gérant. La faire **pointer** aussi.
- **Ronde complète.**
- **Attendu sur A et B** :
  - **une seule** fiche « Nora Test » dans Personnel ;
  - ses pointages des deux tablettes sont sur cette fiche (le même jour ne fait qu'une journée) ;
  - le rôle gardé est **le plus limité** (Employé) ; le taux est celui de la fiche gardée ;
  - un signalement « Employé ajouté deux fois : Nora Test », qui mentionne la différence de taux
    et de rôle.
- [ ] OK

### E1-b — La même CIN dans deux établissements différents
- Le restaurant a deux établissements. **Couper le réseau** sur A et B.
- **A** (établissement 1) : ajouter « Omar Test », PIN `55.55.55-555.55`.
- **B** (établissement 2) : ajouter « Omar Test », même PIN.
- **Ronde complète.**
- **Attendu** : **deux fiches**, une par établissement, rien n'est regroupé, et un signalement
  « Même CIN dans deux établissements : Omar Test ».
- [ ] OK

### E2-a — Deux modifications de champs différents
- **Couper le réseau** sur A et B.
- **A** : changer le **téléphone** de Sara.
- **B** : changer le **nom** de Sara (par exemple « Sara Test-Modif »).
- **Ronde complète.**
- **Attendu sur A et B** : **les deux** changements sont gardés (nouveau téléphone **et** nouveau
  nom), sans signalement.
- [ ] OK

### E2-b — Le même champ modifié des deux côtés (taux)
- **Couper le réseau** sur A et B.
- **A** : taux de Sara → 17 €.
- **B** : taux de Sara → 19 €.
- Remettre le réseau. Synchroniser **A, puis B**, puis A.
- **Attendu sur A et B** : **19 €** (B a envoyé en dernier), et un signalement « Fiche modifiée sur
  deux tablettes : Sara Test » qui parle du taux horaire.
- **Variante rôle** : A met Sara Gérant, B la remet Employé. **Attendu** : la dernière envoyée
  gagne, avec un signalement qui parle du rôle.
- [ ] OK  - [ ] Variante OK

### E2-c — Changé sur A, synchronisé, puis changé sur B (pas un conflit)
- **A** (en ligne) : taux de Sara → 17 €. Synchroniser A, puis B.
- **B** : taux de Sara → 18 €. Synchroniser B, puis A.
- **Attendu** : 18 €, et **aucun** signalement (B avait vu le changement de A).
- [ ] OK

### E3 — Retiré sur A, modifié sur B
- **Couper le réseau** sur A et B.
- **A** : retirer Sara.
- **B** : changer le téléphone de Sara.
- **Ronde complète.**
- **Attendu sur A et B** : Sara reste **retirée**, avec le nouveau téléphone.
- [ ] OK

### E4 — Retiré sur A pendant qu'il pointe sur B
- **Couper le réseau** sur A et B.
- **A** : retirer Karim.
- **B** : Karim → « Pointer », puis « Fin de journée » plus tard.
- **Ronde complète.**
- **Attendu sur A et B** :
  - Karim reste retiré, mais **ses heures sont gardées** ;
  - dans Historique de paiement, Karim apparaît « Retiré », avec ces heures encore dues ;
  - un signalement « Pointage après le retrait : Karim Test ».
- *Restaurer Karim ensuite.*
- [ ] OK

### E5 — Retiré sur A, retiré puis restauré sur B
- **Couper le réseau** sur A et B.
- **A** : retirer Sara.
- **B** : retirer Sara, puis la **Restaurer**.
- Remettre le réseau. Synchroniser **A, puis B**, puis A.
- **Attendu sur A et B** : Sara est **active** (la dernière décision, celle de B, gagne), avec un
  signalement « Fiche modifiée sur deux tablettes : Sara Test ».
- [ ] OK

---

## 6. Les signalements eux-mêmes

### S1 — Un seul signalement, lu séparément
- Reprendre n'importe quel scénario qui crée un signalement (par exemple P4).
- **Attendu** :
  - le signalement apparaît **une seule fois** sur chaque tablette, même si les deux tablettes ont
    réglé le conflit ;
  - un appui ouvre l'historique de l'employé (ou sa page Paiement pour PA1/PA2) ;
  - le **gérant** le marque lu sur A : il reste **non lu pour le propriétaire**, sur A et sur B ;
  - aucun réglage ne permet de couper les signalements « Personnel ».
- [ ] OK

---

## 7. Récapitulatif

| Code | Scénario | Signalement attendu | OK / KO | Remarques |
|---|---|---|---|---|
| L1 | Gérant créé sur A, connexion sur B | — | | |
| L2 | Mauvais PIN, pas de blocage | — | | |
| L3 | Employé refusé à la connexion | — | | |
| L4 | Rôle changé sur A, appliqué sur B | — | | |
| L5 | Employé retiré refusé | — | | |
| P1 | Arrivée sur les deux tablettes | Double pointage | | |
| P3 | Pause sur A, départ sur B | — | | |
| P4 | Deux départs (> 15 min / ≤ 15 min) | Deux départs / aucun | | |
| P5 | Journée ouverte sur les deux | — | | |
| P6-a | Fermeture pendant un service | Pointage après la fermeture | | |
| P6-b | Arrivée après la fermeture | Pointage après la fermeture | | |
| P6-c | Départ après la fermeture (limite) | Deux départs | | |
| H1 | Deux corrections du même départ | Deux départs | | |
| H2 | Correction contre départ pointé | Deux départs | | |
| H3 | Doublon sur un jour payé | — (refus) | | |
| PA1 | Payé sur les deux tablettes | Paiement en double | | |
| PA2 | Changement sur un jour payé | Jour déjà payé | | |
| E6 | Taux changé pendant un paiement | — | | |
| E1-a | Même CIN, même établissement | Employé ajouté deux fois | | |
| E1-b | Même CIN, deux établissements | Même CIN dans deux établissements | | |
| E2-a | Champs différents | — | | |
| E2-b | Même champ (taux / rôle) | Fiche modifiée sur deux tablettes | | |
| E2-c | Changements successifs | — | | |
| E3 | Retiré sur A, modifié sur B | — | | |
| E4 | Retiré sur A, pointe sur B | Pointage après le retrait | | |
| E5 | Retiré sur A, restauré sur B | Fiche modifiée sur deux tablettes | | |
| S1 | Signalement unique, lu séparément | — | | |

**En cas de KO**, noter : le code du scénario, la tablette, ce qui était attendu, ce qu'on a vu,
l'heure, et ce qu'affiche la page « État de la synchronisation » sur les deux tablettes.
