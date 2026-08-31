/// Entité utilisateur, indépendante de la couche de persistance.
class UserEntity {
  final int id;
  final String nom;
  final String login;
  final String role; // 'admin' | 'employe'
  final bool actif;
  final DateTime dateCreation;

  const UserEntity({
    required this.id,
    required this.nom,
    required this.login,
    required this.role,
    required this.actif,
    required this.dateCreation,
  });

  bool get estAdmin => role == 'admin';
}
