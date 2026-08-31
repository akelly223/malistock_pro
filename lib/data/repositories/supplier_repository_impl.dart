import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/suppliers_table.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final AppDatabase db;

  SupplierRepositoryImpl(this.db);

  SupplierEntity _toEntity(Supplier s, Map<int, double> dettes) =>
      SupplierEntity(
        id: s.id,
        nom: s.nom,
        telephone: s.telephone,
        adresse: s.adresse,
        dateCreation: s.dateCreation,
        detteTotale: dettes[s.id] ?? 0,
        estDepot: s.estDepot,
        partAuteurPct: s.partAuteurPct,
      );

  /// Reste à payer par fournisseur, calculé en direct depuis `purchases`
  /// (source unique, pas de V1/V2 à unifier côté achats).
  Future<Map<int, double>> _dettesParFournisseur({int? supplierId}) async {
    final filtre = supplierId != null ? 'AND supplier_id = ?' : '';
    final rows = await db.customSelect(
      '''
      SELECT supplier_id AS supplier_id, SUM(total_final - montant_paye) AS reste
      FROM purchases
      WHERE montant_paye < total_final
        $filtre
      GROUP BY supplier_id
      HAVING SUM(total_final - montant_paye) > 0.01
      ''',
      variables:
          supplierId != null ? [Variable.withInt(supplierId)] : [],
    ).get();

    return {
      for (final row in rows)
        (row.data['supplier_id'] as int):
            (row.data['reste'] as num).toDouble(),
    };
  }

  @override
  Future<List<SupplierEntity>> getAllSuppliers() async {
    final list = await db.suppliersDao.getAllSuppliers();
    final dettes = await _dettesParFournisseur();
    return list.map((s) => _toEntity(s, dettes)).toList();
  }

  @override
  Future<SupplierEntity?> getSupplierById(int id) async {
    final s = await db.suppliersDao.getSupplierById(id);
    if (s == null) return null;
    final dettes = await _dettesParFournisseur(supplierId: id);
    return _toEntity(s, dettes);
  }

  @override
  Future<List<SupplierEntity>> searchSuppliers(String query) async {
    final list = await db.suppliersDao.searchSuppliers(query);
    final dettes = await _dettesParFournisseur();
    return list.map((s) => _toEntity(s, dettes)).toList();
  }

  @override
  Future<int> createSupplier({
    required String nom,
    String? telephone,
    String? adresse,
    bool estDepot = false,
    double partAuteurPct = 0,
  }) {
    return db.suppliersDao.createSupplier(SuppliersCompanion.insert(
      nom: nom,
      telephone: Value(telephone),
      adresse: Value(adresse),
      estDepot: Value(estDepot),
      partAuteurPct: Value(partAuteurPct),
    ));
  }

  @override
  Future<void> updateSupplier(SupplierEntity supplier) async {
    await db.suppliersDao.updateSupplier(Supplier(
      id: supplier.id,
      nom: supplier.nom,
      telephone: supplier.telephone,
      adresse: supplier.adresse,
      dateCreation: supplier.dateCreation,
      estDepot: supplier.estDepot,
      partAuteurPct: supplier.partAuteurPct,
    ));
  }

  @override
  Future<void> deleteSupplier(int id) => db.suppliersDao.deleteSupplier(id);
}
