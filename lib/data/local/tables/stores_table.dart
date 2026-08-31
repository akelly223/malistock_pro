import 'package:drift/drift.dart';

/// Table des magasins / dépôts (multi-magasin).
class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100)();

  TextColumn get adresse => text().nullable()();

  /// Indique le magasin/dépôt principal par défaut.
  BoolColumn get estPrincipal => boolean().withDefault(const Constant(false))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
