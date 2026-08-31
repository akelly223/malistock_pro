import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/store.dart';

final storesListProvider =
    FutureProvider.autoDispose<List<StoreEntity>>((ref) async {
  final repo = ref.watch(storeRepositoryProvider);
  return repo.getAllStores();
});
