import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';

/// Vérifie si un compte administrateur existe déjà (premier lancement
/// de l'application = aucun utilisateur en base).
final hasAdminProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.hasAnyAdmin();
});
