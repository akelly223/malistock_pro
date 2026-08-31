import 'package:drift/drift.dart';

/// Table des brouillons automatiques.
/// Une ligne par type de document (vente, achat, devis, proforma, …).
/// La clé primaire est le type : un seul brouillon par module à la fois.
class Drafts extends Table {
  TextColumn get type => text()();
  TextColumn get donnees => text()();
  DateTimeColumn get dateSauvegarde =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {type};
}
