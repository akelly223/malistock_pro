import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/stores_table.dart';

part 'stores_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoresDao extends DatabaseAccessor<AppDatabase> with _$StoresDaoMixin {
  StoresDao(super.db);

  Future<List<Store>> getAllStores() => select(stores).get();

  Future<Store?> getStoreById(int id) =>
      (select(stores)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Store?> getPrincipalStore() => (select(stores)
        ..where((s) => s.estPrincipal.equals(true)))
      .getSingleOrNull();

  Future<int> createStore(StoresCompanion store) => into(stores).insert(store);

  Future<bool> updateStore(Store store) => update(stores).replace(store);

  Future<int> deleteStore(int id) =>
      (delete(stores)..where((s) => s.id.equals(id))).go();
}
