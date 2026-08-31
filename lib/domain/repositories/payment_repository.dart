import '../entities/payment.dart';
import '../entities/client_debt.dart';

abstract class PaymentRepository {
  Future<List<PaymentEntity>> getAllPayments();
  Future<List<PaymentEntity>> getPaymentsForInvoice(int invoiceId);
  Future<List<PaymentEntity>> getPaymentsForClient(int clientId);

  /// Enregistre un paiement sur une facture précise et met à jour le
  /// statut de paiement + la dette client associée.
  Future<int> registerPaymentForInvoice({
    required int invoiceId,
    required double montant,
    required String modePaiement,
    required int userId,
  });

  /// Enregistre un règlement global sur la dette d'un client,
  /// répartissant le montant sur les dettes les plus anciennes
  /// d'abord (FIFO).
  Future<int> registerPaymentForClientDebt({
    required int clientId,
    required double montant,
    required String modePaiement,
    required int userId,
  });

  Future<List<ClientDebtEntity>> getDebtsForClient(int clientId);

  /// Enregistre un paiement sur un achat fournisseur précis et met à jour
  /// son statut de paiement.
  Future<int> registerPaymentForPurchase({
    required int purchaseId,
    required double montant,
    required String modePaiement,
    required int userId,
  });

  /// Règlement global de dette fournisseur : répartit le montant reçu en
  /// FIFO (plus ancien d'abord) sur les achats impayés de ce fournisseur.
  Future<int> registerPaymentForSupplierDebt({
    required int supplierId,
    required double montant,
    required String modePaiement,
    required int userId,
  });
}
