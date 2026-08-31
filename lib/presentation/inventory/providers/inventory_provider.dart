import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/inventory.dart';

final inventoriesListProvider =
    FutureProvider.autoDispose<List<InventoryEntity>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getAllInventories();
});

final inventoryDetailProvider = FutureProvider.autoDispose
    .family<InventoryEntity?, int>((ref, id) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getInventoryById(id);
});

final inventoryLinesProvider = FutureProvider.autoDispose
    .family<List<InventoryLineEntity>, int>((ref, inventoryId) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getLines(inventoryId);
});
