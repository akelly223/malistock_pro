import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/providers/launch_file_provider.dart';
import 'core/container/temp_workspace_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sûr uniquement parce que le mutex d'instance unique (côté natif,
  // windows/runner/main.cpp) a déjà garanti qu'aucune autre instance
  // de MaliStock Pro ne tourne avant même que ce code Dart ne
  // s'exécute : tout dossier "mstk_session_*" encore présent ne peut
  // venir que d'un crash précédent.
  await TempWorkspaceService.nettoyerDossiersOrphelins();

  final cheminLancement = args.isNotEmpty ? args.first : null;

  runApp(
    ProviderScope(
      overrides: [
        if (cheminLancement != null)
          launchFileProvider.overrideWithValue(cheminLancement),
      ],
      child: const MalistockProApp(),
    ),
  );
}
