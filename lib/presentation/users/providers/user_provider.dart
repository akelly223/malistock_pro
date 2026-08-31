import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/user.dart';

final usersListProvider =
    FutureProvider.autoDispose<List<UserEntity>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllUsers();
});
