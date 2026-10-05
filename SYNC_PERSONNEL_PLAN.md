# Synchronisation du personnel — plan

Branche `feat/sync-personnell-system` = `14-sync-phase-1` (synchro, schéma v20) + `feat/sync-data`
(gestion des employés + corrections de l'audit, schéma v16).

**Périmètre : uniquement** les employés, le tableau de pointage, l'historique de pointage, le
paiement et la connexion des employés.

## Principes

1. **On ne perd jamais une heure travaillée ni un paiement réellement versé.**
2. Quand deux tablettes ne sont pas d'accord, **toutes appliquent la même règle** → tout le monde
   voit la même chose.
3. Sans gravité → réglé tout seul. Douteux → gardé et **signalé au gérant et au propriétaire**.
4. Le serveur reste un miroir : il ne refuse que ce qui ne fait rien perdre (paiement, jour payé).

## Règles validées (2026-10-02)

### Tableau de pointage (plusieurs tablettes de pointage par magasin)
| | Situation | Règle |
|---|---|---|
| P1 | Arrivée pointée sur deux tablettes | un seul jour, les deux arrivées gardées ; le départ ferme **toutes** les arrivées ouvertes ; signalé « double pointage » ; nouvelle action **« Supprimer ce pointage en double »** (gérant, propriétaire) |
| P3 | Pause sur une tablette, départ sur l'autre | le statut (au travail / en pause / terminé) n'est plus copié : **recalculé à partir des heures** ; une pause sans fin se termine au départ |
| P4 | Deux départs pour la même arrivée | on garde **le plus tôt** ; signalé si l'écart dépasse 15 min |
| P5 | Journée ouverte sur deux tablettes | une seule gardée (plus petit identifiant) ; aucun pointage ne bouge |
| P6 | Journée fermée sur une tablette, pointage sur l'autre | la fermeture gagne : une arrivée encore ouverte reçoit un départ à l'heure de fermeture (ses pauses aussi) ; une arrivée pointée après la fermeture est supprimée (et sa journée s'il n'y reste rien) ; chaque cas est signalé. Un jour déjà payé n'est pas touché, seulement signalé |

### Historique de pointage
| | Situation | Règle |
|---|---|---|
| H1 | Deux gérants corrigent le même départ oublié | le plus tôt gagne + signalé |
| H2 | Correction du gérant / départ pointé par l'employé | le plus tôt gagne + signalé |
| H3 | Correction sur un jour payé | voir PA2 |

### Paiement
| | Situation | Règle |
|---|---|---|
| PA1 | Même employé payé sur deux tablettes | le premier paiement arrivé au serveur garde les jours ; le second est gardé, marqué « paiement en double » ; le **trop-versé** (jours payés deux fois) est signalé |
| PA2 | Changement arrivé sur un jour déjà payé | jour **gelé**, montant inchangé ; le changement n'est pas appliqué mais signalé avec la différence (« 1h non payée ») |

### Connexion (révisé le 2026-10-05)
Un gérant ou le propriétaire se connecte avec son **adresse e-mail et son numéro PIN** (la CIN),
déjà sur sa fiche. Il n'y a **plus de mot de passe ni de blocage** après des erreurs : les règles
C1 à C4 (mot de passe partagé, changé deux fois, blocage par tablette, ancien mot de passe hors
ligne) n'ont plus d'objet. La connexion ne lit que la fiche employé, synchronisée comme le reste
(E1 à E6), et n'écrit rien.

### Employés
| | Situation | Règle |
|---|---|---|
| E1 | Même CIN ajouté sur deux tablettes | **fusion** : fiche au plus petit identifiant gardée, pointages et paiements regroupés ; nom/téléphone/email de la fiche gardée ; photo gardée sinon l'autre ; date d'embauche la plus ancienne ; taux de la fiche gardée + signalé ; rôle le plus faible + signalé ; actif si l'une est active. **Magasins différents** : pas de fusion, signalé |
| E2 | Deux modifications de la même fiche | seuls les **champs modifiés** sont envoyés ; même champ → le dernier gagne ; taux ou rôle → signalé |
| E3 | Archivé d'un côté, modifié de l'autre | réglé par E2 : reste archivé |
| E4 | Archivé d'un côté, pointe de l'autre | heures gardées, « retiré mais dû » sur Paiement, signalé |
| E5 | Archivé d'un côté, réactivé de l'autre | la dernière décision gagne + signalé |
| E6 | Taux changé pendant un paiement | pas de conflit : le paiement fige le taux du moment |

## Étapes

Chaque étape : implémentation, tests pointage/personnel uniquement, commit, puis **accord avant la
suivante**.

1. **Finir la fusion** — conflits résolus ; migrations de l'audit renumérotées en **v21**
   (`business_days`, `stores.business_day_auto_open_minutes`,
   `attendance_sessions.exit_set_by_employee_id`) ; filtres `deletedAt` ajoutés au code de l'audit ;
   compile, tests verts.
2. **Synchroniser la journée de service et les nouvelles colonnes** — colonnes de synchro,
   triggers, `SyncTables`, migration Supabase ; règle P5.
3. **Les signalements** — un seul mécanisme pour « signalé au gérant et au propriétaire », visible
   sur toutes les tablettes.
4. **Envoyer seulement les champs modifiés** pour les tables du personnel (E2, E3) — générateur
   de triggers + mise à jour partielle côté serveur.
5. **Identifiants** — séparation mot de passe / état de connexion local (C1–C3). *Remplacé le
   2026-10-05 par la connexion e-mail + PIN : voir ci-dessous.*
6. **Tableau et historique** — statut recalculé (P3), départ qui ferme tout (P1), départ le plus
   tôt (P4, H1, H2), fermeture qui gagne (P6), action « Supprimer ce pointage en double ».
7. **Paiement** — double paiement détecté et signalé (PA1), jour payé gelé côté serveur (PA2).
8. **Employés** — fusion par CIN (E1), signalements E2/E4/E5.
9. **Documentation** — `SYNC_PERSONNELL_EXPLAINED.md`.

## Révision du 2026-10-05

- **P6** : la fermeture de la journée gagne (au lieu de « fermeture et pointage gardés tous les
  deux ») — `d5cab53`.
- **Connexion e-mail + PIN**, sans mot de passe ni blocage, en trois commits :
  1. l'écran de connexion et `authenticate(email, pin)` — `9de98c1` ;
  2. l'assistant employé en deux étapes (« Informations personnelles », « Tarif et rôle »), plus
     de mot de passe à la création du compte — `10412ce` ;
  3. schéma **v22** : `employee_credentials` et `login_states` supprimées, règles C1–C4 retirées
     de la synchro, migration Supabase `20261005000100_no_passwords.sql` — `d730d3d`.
