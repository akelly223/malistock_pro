import '../entities/quote.dart';
import '../entities/cart_item_input.dart';

abstract class QuoteRepository {
  Future<List<QuoteEntity>> getAllQuotes();
  Future<QuoteEntity?> getQuoteById(int id);
  Future<int> createQuote({
    int? clientId,
    required int storeId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  });
  Future<void> deleteQuote(int id);

  /// Met à jour un devis existant : remplace entièrement ses lignes
  /// et recalcule les totaux. Refusé si le devis a déjà été converti
  /// en facture (incohérence sinon entre devis modifié et facture
  /// déjà émise à partir de l'ancienne version).
  Future<void> updateQuote({
    required int quoteId,
    int? clientId,
    required int storeId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  });

  /// Transforme un devis en facture sans ressaisie des lignes.
  /// Retourne l'id de la facture créée.
  Future<int> convertToInvoice(int quoteId, {required int userId});
}
