import 'package:drift/drift.dart';

/// Table des fournisseurs.
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 150)();

  TextColumn get telephone => text().nullable()();

  TextColumn get adresse => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
