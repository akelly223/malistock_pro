import 'package:drift/drift.dart';

/// Taux de TVA applicables (0%, 18%, etc.).
/// Géré en table pour permettre l'ajout de nouveaux taux sans modifier le code.
class TvaRates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Taux en pourcentage, ex: 0.0, 18.0.
  RealColumn get taux => real().unique()();

  /// Libellé affiché, ex: 'Exonéré (0%)', 'TVA normale (18%)'.
  TextColumn get libelle => text().withLength(min: 1, max: 100)();

  BoolColumn get actif => boolean().withDefault(const Constant(true))();
}
