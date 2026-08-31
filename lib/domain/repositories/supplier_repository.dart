import '../entities/supplier.dart';

abstract class SupplierRepository {
  Future<List<SupplierEntity>> getAllSuppliers();
  Future<SupplierEntity?> getSupplierById(int id);
  Future<List<SupplierEntity>> searchSuppliers(String query);
  Future<int> createSupplier({
    required String nom,
    String? telephone,
    String? adresse,
    bool estDepot = false,
    double partAuteurPct = 0,
  });
  Future<void> updateSupplier(SupplierEntity supplier);
  Future<void> deleteSupplier(int id);
}
