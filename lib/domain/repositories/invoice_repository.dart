import '../entities/invoice.dart';
import '../entities/cart_item_input.dart';

abstract class InvoiceRepository {
  Future<List<InvoiceEntity>> getAllInvoices();
  Future<InvoiceEntity?> getInvoiceById(int id);
  Future<List<InvoiceEntity>> getInvoicesForClient(int clientId);
  Future<List<InvoiceEntity>> getInvoicesBetween(DateTime start, DateTime end);
  Future<List<InvoiceEntity>> getUnpaidOrPartialInvoices();

  Future<int> createInvoice({
    int? clientId,
    required int storeId,
    required int userId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
    double montantPayeInitial = 0,
    String? modePaiementInitial,
  });

  /// Modifie une facture existante : annule les effets de l'ancienne
  /// sur le stock, vérifie le stock pour les nouvelles quantités, puis
  /// applique les nouvelles lignes et recalcule le statut de paiement.
  Future<void> updateInvoice({
    required int invoiceId,
    int? clientId,
    required int storeId,
    required int modifieParUserId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  });

  Future<void> deleteInvoice(int id);
}
