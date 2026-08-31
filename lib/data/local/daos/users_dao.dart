import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<List<User>> getAllUsers() => select(users).get();

  Future<User?> getUserByLogin(String login) =>
      (select(users)..where((u) => u.login.equals(login)))
          .getSingleOrNull();

  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> createUser(UsersCompanion user) => into(users).insert(user);

  Future<bool> updateUser(User user) => update(users).replace(user);

  Future<int> deactivateUser(int id) => (update(users)
        ..where((u) => u.id.equals(id)))
      .write(const UsersCompanion(actif: Value(false)));

  /// Vérifie s'il existe déjà au moins un administrateur (utile lors du
  /// premier lancement pour proposer la création du compte admin initial).
  Future<bool> hasAdmin() async {
    final result = await (select(users)
          ..where((u) => u.role.equals('admin')))
        .get();
    return result.isNotEmpty;
  }
}
