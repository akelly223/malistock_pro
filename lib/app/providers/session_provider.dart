import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'repository_providers.dart';

/// État de la session : utilisateur actuellement connecté, ou null
/// si personne n'est connecté (écran de login affiché).
class SessionNotifier extends StateNotifier<UserEntity?> {
  SessionNotifier() : super(null);

  void setUser(UserEntity user) => state = user;

  void logout() => state = null;
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, UserEntity?>((ref) {
  return SessionNotifier();
});

/// Magasin actuellement sélectionné pour les opérations (vente,
/// stock...). Par défaut le magasin principal.
final currentStoreIdProvider = StateProvider<int?>((ref) => null);
