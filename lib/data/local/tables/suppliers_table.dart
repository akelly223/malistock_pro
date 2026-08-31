import 'package:drift/drift.dart';

/// Table des fournisseurs.
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 150)();

  TextColumn get telephone => text().nullable()();

  TextColumn get adresse => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  /// Vrai si ce fournisseur est un auteur en dépôt-vente : les articles
  /// qui lui sont liés ne génèrent pas de dette à la réception, mais à
  /// la vente (cf. [Purchases] fantômes créés par InvoiceRepositoryImpl).
  BoolColumn get estDepot => boolean().withDefault(const Constant(false))();

  /// Pourcentage du prix de vente reversé à l'auteur (0-100), utilisé
  /// uniquement si [estDepot] est vrai.
  RealColumn get partAuteurPct => real().withDefault(const Constant(0))();
}
