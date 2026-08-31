import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/stores_table.dart';
import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';

class StoreRepositoryImpl implements StoreRepository {
  final AppDatabase db;

  StoreRepositoryImpl(this.db);

  StoreEntity _toEntity(Store s) => StoreEntity(
        id: s.id,
        nom: s.nom,
        adresse: s.adresse,
        estPrincipal: s.estPrincipal,
        dateCreation: s.dateCreation,
      );

  @override
  Future<List<StoreEntity>> getAllStores() async {
    final list = await db.storesDao.getAllStores();
    return list.map(_toEntity).toList();
  }

  @override
  Future<StoreEntity?> getStoreById(int id) async {
    final s = await db.storesDao.getStoreById(id);
    return s == null ? null : _toEntity(s);
  }

  @override
  Future<StoreEntity?> getPrincipalStore() async {
    final s = await db.storesDao.getPrincipalStore();
    return s == null ? null : _toEntity(s);
  }

  @override
  Future<int> createStore({
    required String nom,
    String? adresse,
    bool estPrincipal = false,
  }) {
    return db.storesDao.createStore(StoresCompanion.insert(
      nom: nom,
      adresse: Value(adresse),
      estPrincipal: Value(estPrincipal),
    ));
  }

  @override
  Future<void> updateStore(StoreEntity store) async {
    await db.storesDao.updateStore(Store(
      id: store.id,
      nom: store.nom,
      adresse: store.adresse,
      estPrincipal: store.estPrincipal,
      dateCreation: store.dateCreation,
    ));
  }

  @override
  Future<void> deleteStore(int id) => db.storesDao.deleteStore(id);
}
