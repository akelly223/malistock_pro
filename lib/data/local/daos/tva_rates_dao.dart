import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/tva_rates_table.dart';

part 'tva_rates_dao.g.dart';

@DriftAccessor(tables: [TvaRates])
class TvaRatesDao extends DatabaseAccessor<AppDatabase>
    with _$TvaRatesDaoMixin {
  TvaRatesDao(super.db);

  /// Retourne les taux actifs triés par valeur croissante.
  Future<List<TvaRate>> getActifs() =>
      (select(tvaRates)
            ..where((t) => t.actif.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.taux)]))
          .get();

  Future<TvaRate?> getParTaux(double taux) =>
      (select(tvaRates)..where((t) => t.taux.equals(taux))).getSingleOrNull();

  Future<int> inserer(TvaRatesCompanion taux) =>
      into(tvaRates).insert(taux, onConflict: DoUpdate((old) => taux));
}
