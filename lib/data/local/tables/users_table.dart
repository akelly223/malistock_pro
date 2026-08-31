import 'package:drift/drift.dart';

/// Table des utilisateurs (Administrateur / Employé).
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100)();

  TextColumn get login => text().withLength(min: 1, max: 50).unique()();

  /// Mot de passe stocké hashé (jamais en clair).
  TextColumn get motDePasseHash => text()();

  /// 'admin' ou 'employe' — voir DbConstants.
  TextColumn get role => text()();

  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
