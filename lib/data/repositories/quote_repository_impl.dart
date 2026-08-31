import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/quotes_table.dart';
import '../local/tables/invoices_table.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/cart_item_input.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../core/constants/db_constants.dart';
import 'invoice_repository_impl.dart';

class QuoteRepositoryImpl implements QuoteRepository {
  final AppDatabase db;

  QuoteRepositoryImpl(this.db);

  double _calculerTotal(List<CartItemInput> items, double remiseGlobale) {
    final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
    final total = sousTotal - remiseGlobale;
    return total < 0 ? 0 : total;
  }

  Future<QuoteEntity> _toEntity(Quote q) async {
    final itemRows = await db.quotesDao.getItemsForQuote(q.id);
    final items = <QuoteItemEntity>[];
    for (final it in itemRows) {
      final article = await db.articlesDao.getArticleById(it.articleId);
      items.add(QuoteItemEntity(
        id: it.id,
        quoteId: it.quoteId,
        articleId: it.articleId,
        articleNom: article?.nom ?? '???',
        quantite: it.quantite,
        prixUnitaire: it.prixUnitaire,
        remisePourcentage: it.remisePourcentage,
        remiseMontant: it.remiseMontant,
        totalLigne: it.totalLigne,
      ));
    }
    String? clientNom;
    if (q.clientId != null) {
      final c = await db.clientsDao.getClientById(q.clientId!);
      clientNom = c?.nom;
    }
    return QuoteEntity(
      id: q.id,
      numero: q.numero,
      clientId: q.clientId,
      clientNom: clientNom,
      storeId: q.storeId,
      dateCreation: q.dateCreation,
      statut: q.statut,
      totalHt: q.totalHt,
      remiseGlobale: q.remiseGlobale,
      totalFinal: q.totalFinal,
      items: items,
    );
  }

  @override
  Future<List<QuoteEntity>> getAllQuotes() async {
    final quotes = await db.quotesDao.getAllQuotes();
    final result = <QuoteEntity>[];
    for (final q in quotes) {
      result.add(await _toEntity(q));
    }
    return result;
  }

  @override
  Future<QuoteEntity?> getQuoteById(int id) async {
    final q = await db.quotesDao.getQuoteById(id);
    return q == null ? null : _toEntity(q);
  }

  @override
  Future<int> createQuote({
    int? clientId,
    required int storeId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  }) async {
    final numero = await db.quotesDao.generateNextNumero();
    final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
    final totalFinal = _calculerTotal(items, remiseGlobale);

    final quoteId = await db.quotesDao.createQuoteWithItems(
      QuotesCompanion.insert(
        numero: numero,
        clientId: Value(clientId),
        storeId: storeId,
        totalHt: Value(sousTotal),
        remiseGlobale: Value(remiseGlobale),
        totalFinal: Value(totalFinal),
      ),
      items
          .map((i) => QuoteItemsCompanion.insert(
                quoteId: 0, // remplacé par le DAO lors de l'insertion
                articleId: i.articleId,
                quantite: i.quantite,
                prixUnitaire: i.prixUnitaire,
                remisePourcentage: Value(i.remisePourcentage),
                remiseMontant: Value(i.remiseMontant),
                totalLigne: i.totalLigne,
              ))
          .toList(),
    );
    return quoteId;
  }

  @override
  Future<void> deleteQuote(int id) => db.quotesDao.deleteQuote(id);

  @override
  Future<void> updateQuote({
    required int quoteId,
    int? clientId,
    required int storeId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  }) async {
    final existant = await db.quotesDao.getQuoteById(quoteId);
    if (existant == null) {
      throw Exception('Devis introuvable');
    }
    if (existant.statut == DbConstants.quoteStatusConverti) {
      throw Exception(
          'Ce devis a déjà été transformé en facture et ne peut plus être modifié.');
    }

    final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
    final totalFinal = _calculerTotal(items, remiseGlobale);

    await db.quotesDao.replaceItemsAndUpdate(
      QuotesCompanion(
        clientId: Value(clientId),
        storeId: Value(storeId),
        totalHt: Value(sousTotal),
        remiseGlobale: Value(remiseGlobale),
        totalFinal: Value(totalFinal),
      ),
      quoteId,
      items
          .map((i) => QuoteItemsCompanion.insert(
                quoteId: 0, // remplacé par le DAO lors de l'insertion
                articleId: i.articleId,
                quantite: i.quantite,
                prixUnitaire: i.prixUnitaire,
                remisePourcentage: Value(i.remisePourcentage),
                remiseMontant: Value(i.remiseMontant),
                totalLigne: i.totalLigne,
              ))
          .toList(),
    );
  }

  @override
  Future<int> convertToInvoice(int quoteId, {required int userId}) async {
    final quote = await db.quotesDao.getQuoteById(quoteId);
    if (quote == null) {
      throw Exception('Devis introuvable');
    }
    final itemRows = await db.quotesDao.getItemsForQuote(quoteId);

    final cartItems = <CartItemInput>[];
    for (final it in itemRows) {
      final article = await db.articlesDao.getArticleById(it.articleId);
      cartItems.add(CartItemInput(
        articleId: it.articleId,
        articleNom: article?.nom ?? '???',
        quantite: it.quantite,
        prixUnitaire: it.prixUnitaire,
        remisePourcentage: it.remisePourcentage,
        remiseMontant: it.remiseMontant,
      ));
    }

    // Délègue la création réelle de la facture (décrément stock, dette,
    // numérotation) au InvoiceRepositoryImpl pour éviter la duplication
    // de logique métier entre devis et facture.
    final invoiceRepo = InvoiceRepositoryImpl(db);
    final invoiceId = await invoiceRepo.createInvoice(
      clientId: quote.clientId,
      storeId: quote.storeId,
      userId: userId,
      items: cartItems,
      remiseGlobale: quote.remiseGlobale,
    );

    // Lie la facture créée au devis d'origine et marque le devis converti.
    await (db.update(db.invoices)..where((i) => i.id.equals(invoiceId)))
        .write(InvoicesCompanion(quoteId: Value(quoteId)));
    await db.quotesDao.markAsConverti(quoteId);

    return invoiceId;
  }
}
