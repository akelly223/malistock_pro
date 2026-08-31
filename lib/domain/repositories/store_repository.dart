import '../entities/store.dart';

abstract class StoreRepository {
  Future<List<StoreEntity>> getAllStores();
  Future<StoreEntity?> getStoreById(int id);
  Future<StoreEntity?> getPrincipalStore();
  Future<int> createStore({
    required String nom,
    String? adresse,
    bool estPrincipal = false,
  });
  Future<void> updateStore(StoreEntity store);
  Future<void> deleteStore(int id);
}
