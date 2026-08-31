import '../entities/user.dart';

abstract class AuthRepository {
  Future<UserEntity?> login(String loginUser, String motDePasse);
  Future<bool> hasAnyAdmin();
  Future<UserEntity> createUser({
    required String nom,
    required String login,
    required String motDePasse,
    required String role,
  });
  Future<List<UserEntity>> getAllUsers();
  Future<void> deactivateUser(int userId);

  /// Modifie le nom, l'identifiant et le rôle d'un utilisateur existant.
  Future<void> updateUser({
    required int userId,
    required String nom,
    required String login,
    required String role,
  });

  /// Réinitialise le mot de passe d'un utilisateur (action admin).
  Future<void> resetPassword({
    required int userId,
    required String nouveauMotDePasse,
  });
}
