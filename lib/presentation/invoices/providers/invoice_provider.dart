import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/payment.dart';

final invoicesListProvider =
    FutureProvider.autoDispose<List<InvoiceEntity>>((ref) async {
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.getAllInvoices();
});

final invoiceByIdProvider =
    FutureProvider.autoDispose.family<InvoiceEntity?, int>((ref, id) async {
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.getInvoiceById(id);
});

/// Paiements (reçus) enregistrés pour une facture V1 donnée. Une facture
/// payée intégralement dès la vente n'a aucun reçu — la liste est alors
/// vide, la facture faisant foi.
final invoicePaymentsProvider =
    FutureProvider.autoDispose.family<List<PaymentEntity>, int>((ref, invoiceId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPaymentsForInvoice(invoiceId);
});
