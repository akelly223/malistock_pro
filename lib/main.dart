import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app.dart';
import 'app/providers/launch_file_provider.dart';
import 'app/providers/licence_provider.dart';
import 'core/container/temp_workspace_service.dart';
import 'core/licence/licence_config.dart';
import 'core/licence/licence_service.dart';
import 'core/licence/licence_write_guard.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Requis par `CloseSaveGuard` (lib/presentation/container/widgets/
  // close_save_guard.dart) pour intercepter le bouton X et forcer une
  // sauvegarde du conteneur .mstk ouvert avant de quitter réellement.
  await windowManager.ensureInitialized();

  // Sûr uniquement parce que le mutex d'instance unique (côté natif,
  // windows/runner/main.cpp) a déjà garanti qu'aucune autre instance
  // de MaliStock Pro ne tourne avant même que ce code Dart ne
  // s'exécute : tout dossier "mstk_session_*" encore présent ne peut
  // venir que d'un crash précédent.
  await TempWorkspaceService.nettoyerDossiersOrphelins();

  final cheminLancement = args.isNotEmpty ? args.first : null;

  // Essai / licence : calculé avant tout affichage pour que le verrou
  // lecture seule (LicenceWriteGuard) soit posé avant l'ouverture d'un
  // fichier. En cas d'erreur imprévue, on reste en essai plutôt que de
  // bloquer un client honnête.
  final serviceLicence = LicenceService.windows();
  EtatLicence etatLicence;
  try {
    etatLicence = await serviceLicence.charger();
  } catch (_) {
    etatLicence = EtatLicence(
      statut: StatutLicence.essai,
      codePc: serviceLicence.codePc,
      joursRestants: LicenceConfig.joursEssai,
    );
  }
  LicenceWriteGuard.lectureSeule = etatLicence.lectureSeule;

  runApp(
    ProviderScope(
      overrides: [
        licenceServiceProvider.overrideWithValue(serviceLicence),
        etatLicenceInitialProvider.overrideWithValue(etatLicence),
        if (cheminLancement != null)
          launchFileProvider.overrideWithValue(cheminLancement),
      ],
      child: const MalistockProApp(),
    ),
  );
}
