import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/quotes_table.dart';

part 'quotes_dao.g.dart';

@DriftAccessor(tables: [Quotes, QuoteItems])
class QuotesDao extends DatabaseAccessor<AppDatabase> with _$QuotesDaoMixin {
  QuotesDao(super.db);

  Future<List<Quote>> getAllQuotes() =>
      (select(quotes)..orderBy([(q) => OrderingTerm.desc(q.dateCreation)]))
          .get();

  Future<Quote?> getQuoteById(int id) =>
      (select(quotes)..where((q) => q.id.equals(id))).getSingleOrNull();

  Future<List<QuoteItem>> getItemsForQuote(int quoteId) =>
      (select(quoteItems)..where((i) => i.quoteId.equals(quoteId))).get();

  /// Crée un devis avec ses lignes en une seule transaction.
  Future<int> createQuoteWithItems(
    QuotesCompanion quote,
    List<QuoteItemsCompanion> items,
  ) {
    return transaction(() async {
      final quoteId = await into(quotes).insert(quote);
      for (final item in items) {
        await into(quoteItems)
            .insert(item.copyWith(quoteId: Value(quoteId)));
      }
      return quoteId;
    });
  }

  Future<bool> updateQuote(Quote quote) => update(quotes).replace(quote);

  /// Remplace entièrement les lignes d'un devis et met à jour ses
  /// champs scalaires (totaux, remise) en une seule transaction.
  /// Plus simple et plus fiable qu'un diff ligne par ligne pour un
  /// formulaire qui réécrit tout le panier à chaque sauvegarde.
  Future<void> replaceItemsAndUpdate(
    QuotesCompanion quoteUpdate,
    int quoteId,
    List<QuoteItemsCompanion> nouvellesLignes,
  ) {
    return transaction(() async {
      await (delete(quoteItems)..where((i) => i.quoteId.equals(quoteId))).go();
      for (final item in nouvellesLignes) {
        await into(quoteItems)
            .insert(item.copyWith(quoteId: Value(quoteId)));
      }
      await (update(quotes)..where((q) => q.id.equals(quoteId)))
          .write(quoteUpdate);
    });
  }

  Future<void> markAsConverti(int quoteId) =>
      (update(quotes)..where((q) => q.id.equals(quoteId)))
          .write(const QuotesCompanion(statut: Value('converti')));

  Future<int> deleteQuote(int id) =>
      (delete(quotes)..where((q) => q.id.equals(id))).go();

  /// Génère le prochain numéro séquentiel de devis pour l'année en
  /// cours, ex: DEV-2026-0001. Délègue à un compteur dédié, jamais
  /// décrémenté même si un devis est supprimé.
  Future<String> generateNextNumero() =>
      attachedDatabase.documentCountersDao.genererProchainNumero('DEV');
}
