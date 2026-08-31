import '../local/database.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/utils/password_hasher.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AppDatabase db;

  AuthRepositoryImpl(this.db);

  static const int _maxTentatives = 5;
  static const Duration _dureeVerrouillage = Duration(seconds: 30);

  /// Échecs de connexion par identifiant, pour un verrouillage
  /// temporaire anti-brute-force côté UI. En mémoire seulement (reset
  /// au redémarrage de l'app) — protection cosmétique tant que la
  /// base SQLite elle-même n'est pas chiffrée, mais ralentit un
  /// essai manuel répété au clavier.
  final Map<String, _TentativesLogin> _tentatives = {};

  UserEntity _toEntity(User u) => UserEntity(
        id: u.id,
        nom: u.nom,
        login: u.login,
        role: u.role,
        actif: u.actif,
        dateCreation: u.dateCreation,
      );

  @override
  Future<UserEntity?> login(String loginUser, String motDePasse) async {
    final cle = loginUser.trim().toLowerCase();
    final etat = _tentatives[cle];
    if (etat != null && etat.verrouilleJusqua != null) {
      if (DateTime.now().isBefore(etat.verrouilleJusqua!)) {
        throw Exception(
            'Trop de tentatives échouées. Réessayez dans quelques secondes.');
      }
      _tentatives.remove(cle);
    }

    final user = await db.usersDao.getUserByLogin(loginUser);
    final motDePasseValide = user != null &&
        user.actif &&
        PasswordHasher.verify(motDePasse, user.motDePasseHash);

    if (!motDePasseValide) {
      final courant = _tentatives[cle] ?? _TentativesLogin();
      courant.nombre++;
      if (courant.nombre >= _maxTentatives) {
        courant.verrouilleJusqua = DateTime.now().add(_dureeVerrouillage);
      }
      _tentatives[cle] = courant;
      return null;
    }

    _tentatives.remove(cle);

    // Upgrade transparent : un hash encore au format historique
    // (SHA-256 + sel fixe) est remplacé par un hash PBKDF2 dès que le
    // mot de passe en clair est disponible, sans action requise de
    // l'utilisateur.
    if (PasswordHasher.needsRehash(user.motDePasseHash)) {
      await db.usersDao
          .updateUser(user.copyWith(motDePasseHash: PasswordHasher.hash(motDePasse)));
    }

    return _toEntity(user);
  }

  @override
  Future<bool> hasAnyAdmin() => db.usersDao.hasAdmin();

  @override
  Future<UserEntity> createUser({
    required String nom,
    required String login,
    required String motDePasse,
    required String role,
  }) async {
    final existant = await db.usersDao.getUserByLogin(login);
    if (existant != null) {
      throw Exception('Cet identifiant est déjà utilisé par un autre compte.');
    }
    final id = await db.usersDao.createUser(UsersCompanion.insert(
      nom: nom,
      login: login,
      motDePasseHash: PasswordHasher.hash(motDePasse),
      role: role,
    ));
    final user = await db.usersDao.getUserById(id);
    return _toEntity(user!);
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    final users = await db.usersDao.getAllUsers();
    return users.map(_toEntity).toList();
  }

  @override
  Future<void> deactivateUser(int userId) => db.usersDao.deactivateUser(userId);

  @override
  Future<void> updateUser({
    required int userId,
    required String nom,
    required String login,
    required String role,
  }) async {
    final existant = await db.usersDao.getUserByLogin(login);
    if (existant != null && existant.id != userId) {
      throw Exception('Cet identifiant est déjà utilisé par un autre compte.');
    }
    final user = await db.usersDao.getUserById(userId);
    if (user == null) throw Exception('Utilisateur introuvable.');
    await db.usersDao.updateUser(user.copyWith(
      nom: nom,
      login: login,
      role: role,
    ));
  }

  @override
  Future<void> resetPassword({
    required int userId,
    required String nouveauMotDePasse,
  }) async {
    final user = await db.usersDao.getUserById(userId);
    if (user == null) throw Exception('Utilisateur introuvable.');
    await db.usersDao.updateUser(user.copyWith(
      motDePasseHash: PasswordHasher.hash(nouveauMotDePasse),
    ));
  }
}

class _TentativesLogin {
  int nombre = 0;
  DateTime? verrouilleJusqua;
}
