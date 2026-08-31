# Procédure de build — MaliStock Pro

Cette procédure part du principe que l'application fonctionne déjà
en mode développement chez toi (`flutter run -d windows` réussit).

## Étape 0 — Vérifier que le dossier windows natif existe

Si tu n'as jamais lancé `flutter create --platforms=windows .` dans
ce projet (vérifie : le dossier `windows\` doit exister à la racine
du projet), lance-le maintenant :

```
flutter create --platforms=windows .
```

Le point final est important. Cette commande ne touche jamais à ton
code dans `lib\`, elle ajoute seulement le squelette natif Windows
nécessaire pour compiler un exécutable. Si `windows\` existe déjà,
ignore cette étape.

## Étape 1 — Préparer un build de production (pas de mode debug)

À la racine du projet (`malistock_pro\`), dans un terminal :

```
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

`--release` est important : contrairement au mode debug utilisé
jusqu'ici, le mode release est optimisé, démarre plus vite, et c'est
la version que tu donnes à un vrai commerçant — jamais le mode debug.

Si cette commande réussit, tu obtiens un dossier :

```
build\windows\x64\runner\Release\
```

Contenant `malistock_pro.exe`, plusieurs fichiers `.dll`, et un
dossier `data\`. **Les quatre sont indispensables ensemble** — l'exe
seul ne fonctionne pas sans ses DLL et son dossier data.

### Vérification rapide avant de continuer

Double-clique sur `malistock_pro.exe` directement dans ce
dossier Release. L'application doit se lancer normalement (écran de
connexion). Si elle plante immédiatement, ne continue pas vers
l'installateur — corrige d'abord ce problème (vérifie qu'aucun
fichier n'est manquant dans le dossier Release).

## Étape 2 — Installer Inno Setup

Téléchargement gratuit : https://jrsoftware.org/isdl.php
(prends la version stable la plus récente, "isetup-X.X.X.exe").
Installation classique, aucune option particulière à cocher.

## Étape 3 — Préparer les fichiers annexes de l'installateur

Dans le dossier `installer\` du projet (déjà fourni) :

- `setup.iss` — le script Inno Setup, déjà rédigé
- `LICENSE.txt` — le texte de licence affiché à l'installation, déjà rédigé
- `app_icon.ico` — **à fournir toi-même** : une icône au format `.ico`
  (pas `.png`) pour représenter l'application dans le Setup et les
  raccourcis. Si tu n'en as pas, des convertisseurs PNG→ICO gratuits
  existent en ligne (ex: convertio.co/png-ico), ou tu peux temporairement
  retirer la ligne `SetupIconFile=app_icon.ico` du script pour utiliser
  l'icône par défaut d'Inno Setup en attendant.

Vérifie aussi la ligne suivante dans `setup.iss` :

```
#define BuildDir "..\build\windows\x64\runner\Release"
```

Ce chemin est relatif à l'emplacement de `setup.iss`. Si ton dossier
`build` ne se trouve pas exactement là (par exemple si tu as déplacé
le script), ajuste ce chemin.

## Étape 4 — Compiler le Setup.exe

1. Ouvre `installer\setup.iss` avec Inno Setup Compiler (double-clic,
   ou clic droit > "Open with Inno Setup Compiler")
2. Menu **Build > Compile** (ou simplement appuie sur **F9**)
3. Si tout se passe bien, tu obtiens :

```
dist\StockMali_Setup.exe
```

C'est ce fichier unique que tu donnes au commerçant — plus besoin de
lui transmettre le dossier `Release` complet.

### En cas d'erreur de compilation Inno Setup

- **"Source file does not exist"** → le chemin `BuildDir` ne pointe
  pas vers le bon dossier. Vérifie qu'il pointe bien vers
  `build\windows\x64\runner\Release` et que ce dossier contient
  bien `malistock_pro.exe`.
- **"File not found: app_icon.ico"** → soit ajoute ce fichier dans
  `installer\`, soit retire temporairement la ligne `SetupIconFile=...`.

## Étape 5 — Tester l'installateur avant de le livrer

**Ne jamais livrer un Setup.exe non testé.** Sur une machine Windows
(idéalement une machine "propre", sans le projet de développement
installé, pour simuler la machine du commerçant) :

1. Lance `StockMali_Setup.exe`
2. Vérifie l'installation complète (voir checklist de déploiement
   ci-dessous)
3. Lance l'application depuis le raccourci créé
4. Crée le compte admin, accepte ou refuse les données de démo
5. Crée un article, une vente test
6. Ferme l'application, relance-la, vérifie que les données sont
   toujours là
7. Désinstalle via Panneau de configuration > Programmes, vérifie
   que les données restent dans `Documents\MaliStockPro\`
   (volontaire, voir note dans `setup.iss`)

## Mises à jour futures

Pour livrer une nouvelle version :

1. Incrémente `#define MyAppVersion "1.0.1"` (ou suivant) dans `setup.iss`
2. Refais les étapes 1 et 4 (pas besoin de réinstaller Inno Setup)
3. Le nouveau Setup.exe peut être installé par-dessus l'ancienne
   version sans perte de données (le dossier Documents n'est jamais
   touché par Setup, voir note dans `setup.iss`)

Garde toujours le même `AppId` dans `setup.iss` entre les versions —
c'est ce qui permet à Windows de reconnaître qu'il s'agit d'une mise
à jour de la même application, pas d'une nouvelle installation
séparée.
