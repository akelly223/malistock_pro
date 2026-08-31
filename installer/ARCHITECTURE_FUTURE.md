# Notes d'architecture — évolutions futures

Ce document ne décrit pas du code déjà écrit, mais les points
d'ancrage déjà en place dans le projet et ce qu'il faudrait ajouter
pour les deux évolutions demandées. À lire avant de commencer l'une
ou l'autre, pour éviter de redécouvrir ces contraintes à zéro.

## Mise à jour automatique

Rien n'est implémenté actuellement — chaque mise à jour nécessite de
réinstaller manuellement le nouveau `StockMali_Setup.exe` par-dessus
l'ancien (sans perte de données, voir note dans `setup.iss`).

Pour une vraie mise à jour automatique, deux approches possibles :

1. **Vérification manuelle simple** : au démarrage, l'app interroge
   une URL fixe (ex: un fichier JSON sur un serveur ou un simple
   GitHub Release) contenant le numéro de la dernière version
   disponible. Si plus récent que `pubspec.yaml` → afficher un lien
   de téléchargement du nouveau Setup.exe. Pas de téléchargement ni
   d'installation automatique, juste une notification — bien plus
   simple et fiable que l'auto-update silencieux, surtout avec une
   connexion internet instable (contexte malien).

2. **Auto-update complet** (package `auto_updater` ou logique
   maison avec Squirrel/MSIX) : plus complexe, nécessite un serveur
   de distribution fiable, et un mécanisme de rollback en cas
   d'échec. À ne considérer que si l'app est déployée chez beaucoup
   de commerçants et que les mises à jour manuelles deviennent un
   vrai goulot d'étranglement opérationnel.

Recommandation : commencer par l'option 1 si le besoin se confirme.

## Synchronisation cloud

Le projet a déjà été pensé en gardant cette possibilité ouverte,
sans jamais l'avoir implémentée :

- La base est en SQLite local pur (Drift), pas de dépendance à un
  backend pour fonctionner — c'est volontaire, pour garantir le
  fonctionnement hors ligne même sans aucune connexion internet,
  contrainte de départ du projet.
- Les migrations de schéma (`lib/data/local/database.dart`,
  `MigrationStrategy`) sont déjà incrémentales et numérotées
  (`schemaVersion`), ce qui facilitera l'ajout de colonnes de
  synchronisation (ex: `lastModifiedAt`, `syncStatus`, `remoteId`)
  sans casser les installations existantes.
- Le nom "Supabase" a été mentionné comme cible probable dans les
  commentaires du code (`database.dart`) lors de la conception
  initiale, mais aucune dépendance ni code de synchronisation
  n'existe encore.

Pour une vraie synchronisation cloud, il faudrait au minimum :

1. Ajouter à chaque table métier (articles, clients, factures...)
   des colonnes `updatedAt` et un identifiant de synchronisation
2. Un mécanisme de file d'attente locale des changements non
   synchronisés (table dédiée, ou flag sur chaque ligne)
3. Une stratégie de résolution de conflits claire (dernier écrit
   gagne ? fusion manuelle ? — dépend du nombre de postes simultanés)
4. Connexion internet traitée comme un cas optionnel partout dans
   l'app, jamais bloquant pour l'usage quotidien (vente, stock)

Recommandation : ne pas commencer cette évolution avant d'avoir un
besoin réel confirmé (plusieurs postes/magasins à synchroniser entre
eux) — c'est un chantier de plusieurs semaines, pas une option à
activer.
