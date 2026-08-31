import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/suppliers_table.dart';

part 'suppliers_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  Future<List<Supplier>> getAllSuppliers() => select(suppliers).get();

  Future<Supplier?> getSupplierById(int id) =>
      (select(suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Supplier>> searchSuppliers(String query) {
    final likeQuery = '%$query%';
    return (select(suppliers)
          ..where((s) => s.nom.like(likeQuery))
          ..limit(10))
        .get();
  }

  Future<int> createSupplier(SuppliersCompanion supplier) =>
      into(suppliers).insert(supplier);

  Future<bool> updateSupplier(Supplier supplier) =>
      update(suppliers).replace(supplier);

  Future<int> deleteSupplier(int id) =>
      (delete(suppliers)..where((s) => s.id.equals(id))).go();
}
