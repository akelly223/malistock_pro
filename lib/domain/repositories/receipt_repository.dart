import '../entities/payment_receipt.dart';

abstract class ReceiptRepository {
  /// Tous les reçus de paiement (ventes V1/V2 + achats), du plus récent
  /// au plus ancien.
  Future<List<PaymentReceiptEntity>> getAllReceipts();

  /// Un reçu précis, identifié par sa source ('v2' | 'v1_facture' | 'achat')
  /// et l'id de la ligne de paiement d'origine.
  Future<PaymentReceiptEntity?> getReceiptById(String source, int paymentId);
}
