import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/purchase.dart';

final purchaseSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredPurchasesProvider =
    FutureProvider.autoDispose<List<PurchaseEntity>>((ref) async {
  final query = ref.watch(purchaseSearchQueryProvider);
  final repo = ref.watch(purchaseRepositoryProvider);
  if (query.trim().isEmpty) return repo.getAllPurchases();
  return repo.searchPurchases(query.trim());
});

final purchaseByIdProvider =
    FutureProvider.autoDispose.family<PurchaseEntity?, int>((ref, id) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchaseById(id);
});

final purchasesForSupplierProvider = FutureProvider.autoDispose
    .family<List<PurchaseEntity>, int>((ref, supplierId) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchasesForSupplier(supplierId);
});

final totalAchatsForSupplierProvider =
    FutureProvider.autoDispose.family<double, int>((ref, supplierId) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getTotalAchatsForSupplier(supplierId);
});
