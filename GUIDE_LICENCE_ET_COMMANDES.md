# Guide — Licences et commandes utiles (MaliStock Pro)

Toutes les commandes se tapent dans un terminal (PowerShell ou le terminal
de VS Code), **à la racine du projet** :

```powershell
cd C:\Users\kelly\Documents\flutter_desktop_app\malistock_pro
```

---

## Partie 1 — Licences

### Comment ça marche (en résumé)

| Moment | Ce que voit le client |
|---|---|
| Jours 1 à 75 | Tout fonctionne, aucun message |
| 15 derniers jours | Bandeau orange « Il vous reste X jours d'essai gratuit » |
| Après 90 jours | Bandeau rouge, **lecture seule** : il peut consulter, imprimer, exporter, sauvegarder, mais plus enregistrer de nouvelles opérations |
| Après activation | Tout est débloqué, pour toujours, sur ce PC |

- Une clé = **un seul PC** et **une seule application**.
- Code produit de cette application : **`MSP1`**.
  (gestion_commerciale = `GCO1`, mali_pneus = `MPN1` — chaque projet a son propre outil.)

### Vendre une licence, étape par étape

**1. Le client t'envoie son code PC**

Chez lui : **Paramètres › Licence** → bouton « Copier » à côté du code PC.
Exemple de code : `EG2F-Y5RN-6SDM-HNYQ`

**2. Le client paie** (Orange Money / Moov Money)

**3. Tu génères sa clé** (depuis le dossier de CETTE application) :

```powershell
dart run tool/generer_licence.dart EG2F-Y5RN-6SDM-HNYQ
```

Résultat affiché :

```
Produit : MSP1
Code PC : EG2F-Y5RN-6SDM-HNYQ

Clé de licence à envoyer au client :

XXXXXXXX-XXXXXXXX-XXXXXXXX-... (longue clé)
```

**4. Tu lui envoies la clé par WhatsApp**

Il la colle dans **Paramètres › Licence** puis clique **« Activer »**.
C'est terminé, la licence est à vie.

> Les espaces, tirets, retours à la ligne et minuscules sont tolérés :
> un copier-coller depuis WhatsApp fonctionne.

### Le client dit « Clé refusée » : que vérifier

| Cause probable | Solution |
|---|---|
| Clé générée depuis le **mauvais projet** (ex. depuis mali_pneus pour un client MaliStock Pro) | Refaire la commande depuis `malistock_pro` |
| Code PC mal recopié | Demander une capture d'écran de Paramètres › Licence |
| Clé incomplète (coupée dans le message) | Renvoyer la clé en un seul message |
| Le client a **réinstallé Windows** ou changé de PC | Son code PC a changé : générer une nouvelle clé (gratuitement, il a déjà payé) |

Pour générer une clé d'une autre application sans changer de dossier :

```powershell
dart run tool/generer_licence.dart --produit GCO1 CODE-PC-DU-CLIENT
dart run tool/generer_licence.dart --produit MPN1 CODE-PC-DU-CLIENT
```

### ⚠️ La clé secrète

Fichier : `C:\Users\kelly\.malicode\cle_privee_licence.txt`

- C'est **le seul moyen** de fabriquer des clés (pour les 3 applications).
- **Ne jamais le partager**, ne jamais le mettre dans git ou l'envoyer par WhatsApp.
- Garder **au moins 2 copies** de sauvegarde (Drive protégé + clé USB).
- Les clés déjà vendues continuent de fonctionner même si ce fichier est perdu ;
  mais sans lui, impossible d'en créer de nouvelles.

**Sur un nouveau PC** : copier le fichier depuis la sauvegarde vers
`C:\Users\<ton nom>\.malicode\cle_privee_licence.txt`, et l'outil refonctionne.

**Ne JAMAIS relancer** la commande suivante (déjà faite le 07/10/2026) :

```powershell
dart run tool/generer_licence.dart init
```

Elle crée une nouvelle paire de clés. L'outil refuse d'écraser la clé
existante, mais si le fichier avait disparu elle en créerait une nouvelle,
incompatible avec les logiciels déjà installés chez les clients.

### Remettre l'essai à zéro sur TON PC (pour tester)

Utile pour revoir l'écran d'essai après avoir activé une licence chez toi.
Les informations sont stockées à **deux endroits** ; il faut supprimer les deux.

```powershell
Remove-Item "$env:APPDATA\com.example\malistock_pro\cfg_*.dat"
reg delete "HKCU\Software\MaliCodeCenter\Msp\Cfg" /f
```

Au prochain lancement, l'essai repart à 90 jours. (Ne jamais donner ces
commandes à un client.)

---

## Partie 2 — Commandes utiles

### Développement au quotidien

| Commande | À quoi ça sert |
|---|---|
| `flutter run -d windows` | Lancer l'application en mode développement |
| `flutter pub get` | Télécharger les paquets (après une modification de `pubspec.yaml`, ou après un `git pull`) |
| `flutter analyze` | Chercher les erreurs dans le code sans lancer l'application |
| `dart format .` | Remettre en forme proprement tout le code |
| `flutter test` | Lancer tous les tests automatiques |
| `flutter test test/licence_test.dart` | Lancer un seul fichier de tests |

**Pendant que `flutter run` tourne**, dans le terminal :

| Touche | Effet |
|---|---|
| `r` | Recharger rapidement après une modification (hot reload) |
| `R` | Redémarrer complètement l'application (hot restart) |
| `q` | Quitter |

### Génération de code (base de données, providers)

À lancer après avoir modifié une table de la base (`lib/data/local/tables/`),
un DAO, ou un fichier qui contient `part '....g.dart';` :

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Version qui régénère automatiquement à chaque sauvegarde (pratique pendant le travail) :

```powershell
dart run build_runner watch --delete-conflicting-outputs
```

### Construire une version pour les clients

**1. Changer le numéro de version** — aux **3 endroits**, avec le même numéro :

| Fichier | Ligne |
|---|---|
| `pubspec.yaml` | `version: 3.5.0+5` (le nombre après `+` augmente de 1 à chaque version) |
| `lib/core/constants/app_identity.dart` | `static const String version = '3.5.0';` |
| `installer/setup.iss` | `#define MyAppVersion "3.5.0"` |

**2. Construire l'application** (build propre, mode release) :

```powershell
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

Résultat : `build\windows\x64\runner\Release\malistock_pro.exe`
(+ les `.dll` et le dossier `data\`, indispensables ensemble).
Double-clique dessus pour vérifier qu'il se lance avant de continuer.

**3. Créer l'installateur** (Inno Setup) :

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup.iss
```

(ou ouvrir `installer\setup.iss` dans Inno Setup et appuyer sur **F9**)

Résultat : `dist\MaliStock Pro_Setup.exe` — c'est ce fichier que tu donnes aux clients.

Procédure détaillée : `installer\PROCEDURE_BUILD.md`.

### Quand quelque chose ne marche plus

| Problème | Commande |
|---|---|
| Erreurs bizarres de compilation après une mise à jour | `flutter clean` puis `flutter pub get` |
| Erreur « ... .g.dart » ou « isn't defined » après modif de la base | `dart run build_runner build --delete-conflicting-outputs` |
| Vérifier que Flutter et Visual Studio sont bien installés | `flutter doctor` |
| Voir les paquets qui ont une nouvelle version | `flutter pub outdated` |
| Mettre à jour les paquets (prudence : tester après) | `flutter pub upgrade` |

### Git (sauvegarder et publier le code)

| Commande | À quoi ça sert |
|---|---|
| `git status` | Voir les fichiers modifiés |
| `git diff` | Voir le détail des modifications |
| `git add lib test tool` | Préparer les fichiers à enregistrer (éviter `git add .` qui embarquerait `dist\*.exe`) |
| `git commit -m "message"` | Enregistrer une version |
| `git push` | Envoyer sur GitHub |
| `git pull` | Récupérer les dernières modifications depuis GitHub |
| `git log --oneline -10` | Voir les 10 dernières versions enregistrées |
