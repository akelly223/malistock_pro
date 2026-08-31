import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/client.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/payment.dart';

final clientSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredClientsProvider =
    FutureProvider.autoDispose<List<ClientEntity>>((ref) async {
  final query = ref.watch(clientSearchQueryProvider);
  final repo = ref.watch(clientRepositoryProvider);
  if (query.trim().isEmpty) return repo.getAllClients();
  return repo.searchClients(query.trim());
});

final clientByIdProvider =
    FutureProvider.autoDispose.family<ClientEntity?, int>((ref, id) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getClientById(id);
});

final clientHistoriqueAchatsProvider =
    FutureProvider.autoDispose.family<List<InvoiceEntity>, int>((ref, id) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getHistoriqueAchats(id);
});

final clientHistoriquePaiementsProvider =
    FutureProvider.autoDispose.family<List<PaymentEntity>, int>((ref, id) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getHistoriquePaiements(id);
});
