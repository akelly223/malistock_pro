import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chemin du fichier `.mstk` passé en argument au lancement de l'app
/// (double-clic sur un fichier, `main.dart` reçoit `args`), ou `null`
/// si l'app a été lancée sans fichier — dans ce cas l'écran d'accueil
/// s'affiche normalement.
///
/// Valeur fixée une seule fois via un override de `ProviderScope` dans
/// `main.dart` ; jamais modifiée après coup (une ouverture ultérieure
/// passe par `activeContainerProvider`, pas par celui-ci).
final launchFileProvider = Provider<String?>((ref) => null);
