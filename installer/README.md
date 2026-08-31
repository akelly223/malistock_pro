# Dossier installer/ — Vue d'ensemble

Ce dossier contient tout ce qu'il faut pour transformer le projet
Flutter en un véritable installateur Windows professionnel
(StockMali_Setup.exe).

## Fichiers de ce dossier

- **`setup.iss`** — Script Inno Setup, à ouvrir avec Inno Setup
  Compiler sur Windows. Génère le Setup.exe final.
- **`LICENSE.txt`** — Texte affiché à l'utilisateur pendant
  l'installation (déjà rédigé, modifiable si besoin).
- **`app_icon.ico`** — **à fournir toi-même** (pas inclus), icône de
  l'application au format .ico.
- **`PROCEDURE_BUILD.md`** — Procédure complète, étape par étape,
  pour générer l'exe Flutter puis le Setup.exe avec Inno Setup.
- **`CHECKLIST_DEPLOIEMENT.md`** — Checklist à utiliser avant et
  pendant chaque installation chez un commerçant réel.
- **`ARCHITECTURE_FUTURE.md`** — Notes pour les évolutions futures
  (mise à jour automatique, synchronisation cloud) : ce qui existe
  déjà comme point d'ancrage, ce qu'il faudrait construire.

## Par où commencer

1. Lis `PROCEDURE_BUILD.md` du début à la fin avant de lancer quoi
   que ce soit.
2. Fournis `app_icon.ico` (ou retire temporairement la ligne
   correspondante dans `setup.iss`).
3. Suis les 5 étapes de `PROCEDURE_BUILD.md`.
4. Avant toute livraison réelle, parcours `CHECKLIST_DEPLOIEMENT.md`
   intégralement — ne pas sauter cette étape, même pour une
   installation "de test" chez un commerçant.

## Ce qui a été ajouté côté application pour cette livraison

- Service de données de démonstration (`lib/core/services/demo_data_service.dart`),
  proposé sous forme de bouton après la création du compte admin au
  premier lancement — pas géré par l'installateur lui-même, pour des
  raisons de fiabilité technique (Inno Setup ne peut pas écrire dans
  SQLite de façon sûre).
- Sauvegarde automatique quotidienne silencieuse au démarrage de
  l'application (`lib/core/services/backup_service.dart`,
  méthode `sauvegarderAutomatiquementSiNecessaire`), en complément
  de la sauvegarde manuelle déjà existante dans Paramètres.

## Ce qui n'a pas été construit (volontairement)

- Assistant de configuration en 3 écrans séparés (entreprise → logo
  → admin) : tu as choisi de garder l'écran de premier lancement
  actuel en une seule étape.
- Mise à jour automatique et synchronisation cloud : non implémentées,
  voir `ARCHITECTURE_FUTURE.md` pour les pistes si le besoin se
  confirme plus tard.
