; ============================================================
; Script Inno Setup — MaliStock Pro
; ============================================================
; À compiler avec Inno Setup (https://jrsoftware.org/isinfo.php)
; sur une machine Windows, après avoir généré le build Flutter
; (voir installer/PROCEDURE_BUILD.md pour les étapes complètes).
;
; Ouvrir ce fichier dans Inno Setup Compiler, puis Build > Compile
; (ou F9), produit dist\MaliStock_Setup.exe
; ============================================================

#define MyAppName "MaliStock Pro"
#define MyAppShortName "MaliStock Pro"
#define MyAppVersion "3.5.0"
#define MyAppPublisher "MALI_CODE CENTER"
#define MyAppExeName "malistock_pro.exe"
; Association du format de fichier de données .mstk (voir [Registry]
; ci-dessous). ProgID arbitraire mais stable — ne pas renommer une
; fois publié, des utilisateurs en dépendraient déjà pour ouvrir leurs
; fichiers par double-clic.
#define MyAppAssocExt ".mstk"
#define MyAppAssocKey "MaliStockPro.Dossier"
; Chemin vers le dossier généré par `flutter build windows`, relatif
; à ce fichier .iss. À ajuster si l'emplacement diffère chez vous.
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant unique généré une seule fois pour cette application —
; NE JAMAIS CHANGER entre les versions, sinon Windows considère
; chaque mise à jour comme une application différente.
AppId={{F3BDCC0E-E93F-4725-A77B-063D747D85BC}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://facebook.com/mlcode223
AppSupportURL=https://facebook.com/mlcode223
; Suggestion par défaut seulement — comme tout installateur pro
; (Office, Adobe, etc.), l'utilisateur reste libre de choisir un
; autre dossier, y compris sur un autre disque (D:, E:, une clé USB,
; un NAS...), via la page "Sélection du dossier de destination" et
; son bouton Parcourir (voir DisableDirPage ci-dessous).
DefaultDirName={autopf}\{#MyAppShortName}
DefaultGroupName={#MyAppShortName}
; Dossier de sortie du Setup.exe généré.
OutputDir=..\dist
OutputBaseFilename={#MyAppShortName}_Setup
Compression=lzma2/max
SolidCompression=yes
; Setup.exe lui-même nécessite des droits admin (installation dans
; Program Files), mais l'application une fois installée tourne en
; utilisateur standard — voir [Run] et la note sur les données.
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Icône affichée dans le panneau Programmes et fonctionnalités.
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
WizardStyle=modern
SetupIconFile=app_icon.ico
DisableProgramGroupPage=yes
LicenseFile=LICENSE.txt
; ── Choix du dossier d'installation, comme les logiciels pro ───────
; DisableDirPage=no (le défaut d'Inno Setup) affiche la page
; "Sélection du dossier de destination" avec un bouton Parcourir :
; l'utilisateur peut alors installer sur n'importe quel disque, pas
; seulement C:. Mis ici explicitement pour que ce choix ne soit
; jamais supprimé par erreur dans une future modification.
DisableDirPage=no
; Sur une mise à jour, ré-utilise automatiquement le dossier choisi
; lors de la première installation au lieu de reproposer {autopf} —
; comportement standard des installateurs professionnels.
UsePreviousAppDir=yes
UsePreviousGroup=yes
; Rappelle le dossier choisi sur la dernière page avant l'installation
; (« Prêt à installer »), pour que l'utilisateur puisse vérifier /
; revenir en arrière avant de valider.
AlwaysShowDirOnReadyPage=yes
AlwaysShowGroupOnReadyPage=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
; Cases à cocher proposées pendant l'installation. La case "Lancer
; au démarrage de Windows" est optionnelle et décochée par défaut —
; un commerçant lance lui-même son logiciel, pas besoin de forcer.
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"; Flags: checkedonce
Name: "startupicon"; Description: "Lancer {#MyAppShortName} au démarrage de Windows"; GroupDescription: "Options :"; Flags: unchecked

[Files]
; Copie tout le contenu du build Release Flutter (exe + DLL +
; data\flutter_assets) — Source avec \*, pas juste le .exe seul,
; car Flutter Windows a besoin de ses DLL et assets pour fonctionner.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; Association du format de fichier .mstk : double-cliquer un fichier
; .mstk lance MaliStock Pro avec son chemin en argument (voir
; windows/runner/main.cpp). HKCR (racine de la fusion HKLM/HKCU) est
; cohérent avec PrivilegesRequired=admin ci-dessus.
Root: HKCR; Subkey: "{#MyAppAssocExt}"; ValueType: string; ValueName: ""; \
    ValueData: "{#MyAppAssocKey}"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "{#MyAppAssocKey}"; ValueType: string; ValueName: ""; \
    ValueData: "Dossier de données MaliStock Pro"; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#MyAppAssocKey}\DefaultIcon"; ValueType: string; \
    ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "{#MyAppAssocKey}\shell\open\command"; ValueType: string; \
    ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Icons]
; Menu Démarrer (toujours créé).
Name: "{group}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Désinstaller {#MyAppShortName}"; Filename: "{uninstallexe}"
; Bureau (seulement si la case correspondante est cochée).
Name: "{autodesktop}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Démarrage automatique de Windows (optionnel, décoché par défaut).
Name: "{userstartup}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; Propose de lancer l'application immédiatement après l'installation.
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer {#MyAppShortName} maintenant"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; IMPORTANT : on NE supprime PAS le dossier de données utilisateur
; (Documents\MaliStockPro, contenant la base SQLite, les PDF
; et les sauvegardes) à la désinstallation. Cette section ne
; nettoie que des fichiers temporaires éventuels dans {app}, jamais
; les données métier du commerçant. Voir la note "DONNÉES" en bas
; de ce fichier pour le détail de cette décision.
Type: filesandordirs; Name: "{app}\data\flutter_assets\.last_build_id"

[Code]
const
  SHCNE_ASSOCCHANGED = $08000000;
  SHCNF_IDLIST = $0000;

procedure SHChangeNotify(wEventId: Longint; uFlags: Longint; dwItem1, dwItem2: Longint);
  external 'SHChangeNotify@shell32.dll stdcall';

{ Vérifie au lancement de l'installateur si une version est déjà
  installée, pour informer l'utilisateur qu'il s'agit d'une mise à
  jour (les données existantes ne sont jamais touchées par Setup,
  uniquement les fichiers programme dans Program Files). }
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

{ Après installation, notifie l'Explorateur que l'association .mstk
  vient de changer, pour que la nouvelle icône/commande soit prise en
  compte sans redémarrage de session. }
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
  end;
end;

{ ============================================================
  NOTE IMPORTANTE SUR LES DONNÉES (à lire avant toute modification
  de ce script) :

  L'application stocke toutes les données du commerçant (base
  SQLite, PDF générés, logo, sauvegardes) dans :
    C:\Users\<utilisateur>\Documents\MaliStockPro\

  Ce dossier est CRÉÉ ET GÉRÉ PAR L'APPLICATION ELLE-MÊME au premier
  lancement (voir lib/data/local/database.dart côté code source),
  PAS par cet installateur. Conséquences :

  - Désinstaller puis réinstaller l'application NE SUPPRIME JAMAIS
    les données du commerçant, puisque Setup ne touche qu'au dossier
    Program Files, jamais à Documents.
  - Une mise à jour future (nouvelle version de l'exe) n'écrasera
    jamais la base de données existante.
  - Pour un vrai nettoyage complet (rare, demandé explicitement par
    le commerçant), il faudrait supprimer ce dossier manuellement —
    ce script ne le fait jamais automatiquement, par sécurité.
  ============================================================ }
