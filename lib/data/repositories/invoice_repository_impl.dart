import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/invoices_table.dart';
import '../local/tables/client_debts_table.dart';
import '../local/tables/payments_table.dart';
import '../local/tables/stock_movements_table.dart';
import '../local/tables/purchases_table.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/cart_item_input.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/exceptions/stock_insuffisant_exception.dart';
import '../../core/constants/db_constants.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final AppDatabase db;

  InvoiceRepositoryImpl(this.db);

  double _calculerTotal(List<CartItemInput> items, double remiseGlobale) {
    final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
    final total = sousTotal - remiseGlobale;
    return total < 0 ? 0 : total;
  }

  Future<InvoiceEntity> _toEntity(Invoice inv) async {
    final itemRows = await db.invoicesDao.getItemsForInvoice(inv.id);
    final items = <InvoiceItemEntity>[];
    for (final it in itemRows) {
      final article = await db.articlesDao.getArticleById(it.articleId);
      items.add(InvoiceItemEntity(
        id: it.id,
        invoiceId: it.invoiceId,
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
    String? clientTelephone;
    String? clientAdresse;
    String? clientNif;
    if (inv.clientId != null) {
      final c = await db.clientsDao.getClientById(inv.clientId!);
      clientNom = c?.nom;
      clientTelephone = c?.telephone;
      clientAdresse = c?.adresse;
      clientNif = c?.nif;
    }
    final store = await db.storesDao.getStoreById(inv.storeId);
    final user = await db.usersDao.getUserById(inv.userId);
    final modifiePar = inv.modifieParUserId != null
        ? await db.usersDao.getUserById(inv.modifieParUserId!)
        : null;
    return InvoiceEntity(
      id: inv.id,
      numero: inv.numero,
      clientId: inv.clientId,
      clientNom: clientNom,
      clientTelephone: clientTelephone,
      clientAdresse: clientAdresse,
      clientNif: clientNif,
      storeId: inv.storeId,
      storeNom: store?.nom,
      quoteId: inv.quoteId,
      userId: inv.userId,
      userNom: user?.nom,
      dateCreation: inv.dateCreation,
      totalHt: inv.totalHt,
      remiseGlobale: inv.remiseGlobale,
      totalFinal: inv.totalFinal,
      montantPaye: inv.montantPaye,
      statutPaiement: inv.statutPaiement,
      items: items,
      dateModification: inv.dateModification,
      modifieParNom: modifiePar?.nom,
    );
  }

  @override
  Future<List<InvoiceEntity>> getAllInvoices() async {
    final invoices = await db.invoicesDao.getAllInvoices();
    final result = <InvoiceEntity>[];
    for (final inv in invoices) {
      result.add(await _toEntity(inv));
    }
    return result;
  }

  @override
  Future<InvoiceEntity?> getInvoiceById(int id) async {
    final inv = await db.invoicesDao.getInvoiceById(id);
    return inv == null ? null : _toEntity(inv);
  }

  @override
  Future<List<InvoiceEntity>> getInvoicesForClient(int clientId) async {
    final invoices = await db.invoicesDao.getInvoicesForClient(clientId);
    final result = <InvoiceEntity>[];
    for (final inv in invoices) {
      result.add(await _toEntity(inv));
    }
    return result;
  }

  @override
  Future<List<InvoiceEntity>> getInvoicesBetween(
      DateTime start, DateTime end) async {
    final invoices = await db.invoicesDao.getInvoicesBetween(start, end);
    final result = <InvoiceEntity>[];
    for (final inv in invoices) {
      result.add(await _toEntity(inv));
    }
    return result;
  }

  @override
  Future<List<InvoiceEntity>> getUnpaidOrPartialInvoices() async {
    final invoices = await db.invoicesDao.getUnpaidOrPartialInvoices();
    final result = <InvoiceEntity>[];
    for (final inv in invoices) {
      result.add(await _toEntity(inv));
    }
    return result;
  }

  /// Crée une facture complète : décrémente le stock par article,
  /// enregistre les mouvements de stock, calcule le statut de
  /// paiement, et crée une dette client si la facture n'est pas
  /// totalement payée à la création.
  @override
  Future<int> createInvoice({
    int? clientId,
    required int storeId,
    required int userId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
    double montantPayeInitial = 0,
    String? modePaiementInitial,
  }) async {
    return db.transaction(() async {
      // Vérifie la disponibilité du stock pour chaque article avant
      // toute écriture : une vente ne doit jamais faire passer le
      // stock sous zéro. Fait à l'intérieur de la transaction pour
      // qu'aucune ligne ne soit insérée si un seul article manque,
      // et regroupe les quantités par article pour gérer le cas où
      // le même article apparaît plusieurs fois dans le panier.
      final quantitesParArticle = <int, double>{};
      for (final item in items) {
        quantitesParArticle[item.articleId] =
            (quantitesParArticle[item.articleId] ?? 0) + item.quantite;
      }
      for (final entry in quantitesParArticle.entries) {
        final stockDisponible = await db.articlesDao
            .getStockForArticleInStore(entry.key, storeId);
        if (stockDisponible < entry.value) {
          final article = await db.articlesDao.getArticleById(entry.key);
          throw StockInsuffisantException(
            articleNom: article?.nom ?? 'Article inconnu',
            stockDisponible: stockDisponible,
            quantiteDemandee: entry.value,
          );
        }
      }

      final numero = await db.invoicesDao.generateNextNumero();
      final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
      final totalFinal = _calculerTotal(items, remiseGlobale);

      String statutPaiement;
      if (montantPayeInitial >= totalFinal && totalFinal > 0) {
        statutPaiement = DbConstants.invoiceStatusPaye;
      } else if (montantPayeInitial > 0) {
        statutPaiement = DbConstants.invoiceStatusPartiel;
      } else {
        statutPaiement = DbConstants.invoiceStatusNonPaye;
      }

      final invoiceId = await db.invoicesDao.createInvoiceWithItems(
        InvoicesCompanion.insert(
          numero: numero,
          clientId: Value(clientId),
          storeId: storeId,
          userId: userId,
          totalHt: Value(sousTotal),
          remiseGlobale: Value(remiseGlobale),
          totalFinal: Value(totalFinal),
          montantPaye: Value(montantPayeInitial),
          statutPaiement: Value(statutPaiement),
        ),
        items
            .map((i) => InvoiceItemsCompanion.insert(
                  invoiceId: 0, // remplacé par le DAO lors de l'insertion
                  articleId: i.articleId,
                  quantite: i.quantite,
                  prixUnitaire: i.prixUnitaire,
                  remisePourcentage: Value(i.remisePourcentage),
                  remiseMontant: Value(i.remiseMontant),
                  totalLigne: i.totalLigne,
                ))
            .toList(),
      );

      // Décrémente le stock et trace chaque sortie.
      for (final item in items) {
        await db.articlesDao.adjustStock(
          articleId: item.articleId,
          storeId: storeId,
          delta: -item.quantite,
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: item.articleId,
          storeId: storeId,
          typeMouvement: DbConstants.movementSortie,
          quantite: item.quantite,
          reference: Value(numero),
          userId: userId,
        ));
      }

      // Dépôt-vente : pour chaque ligne vendue dont l'article appartient
      // à un auteur en dépôt, génère un achat fournisseur "fantôme" non
      // payé représentant la part due à l'auteur. Contrairement à un
      // achat normal, on insère directement via le DAO (pas de mouvement
      // de stock ni de mise à jour de prix_achat : le stock a déjà été
      // mouvementé par la vente ci-dessus).
      for (final item in items) {
        final article = await db.articlesDao.getArticleById(item.articleId);
        if (article?.supplierId == null) continue;
        final supplier =
            await db.suppliersDao.getSupplierById(article!.supplierId!);
        if (supplier == null || !supplier.estDepot) continue;
        if (supplier.partAuteurPct <= 0) continue;

        final montantDu = item.totalLigne * supplier.partAuteurPct / 100;
        if (montantDu <= 0) continue;

        final numeroDepot =
            await db.documentCountersDao.genererProchainNumero('DEP');
        await db.purchasesDao.createPurchaseWithItems(
          PurchasesCompanion.insert(
            numero: numeroDepot,
            supplierId: supplier.id,
            storeId: storeId,
            userId: userId,
            totalHt: Value(montantDu),
            totalFinal: Value(montantDu),
            montantPaye: const Value(0),
            statutPaiement: const Value(DbConstants.invoiceStatusNonPaye),
          ),
          [
            PurchaseItemsCompanion.insert(
              purchaseId: 0,
              articleId: item.articleId,
              quantite: item.quantite,
              prixAchatUnitaire: montantDu / item.quantite,
              totalLigne: montantDu,
            ),
          ],
        );
      }

      // Enregistre le paiement initial s'il y en a un. Un reçu ne se
      // justifie que si la facture reste débitrice après ce paiement :
      // si le client règle tout dès la vente, la facture suffit comme
      // preuve et aucun reçu n'est créé.
      final resteAPayer = totalFinal - montantPayeInitial;
      if (montantPayeInitial > 0 &&
          modePaiementInitial != null &&
          resteAPayer > 0.01) {
        final numeroRecu =
            await db.documentCountersDao.genererProchainNumero('REC');
        await db.paymentsDao.createPayment(PaymentsCompanion.insert(
          invoiceId: Value(invoiceId),
          clientId: Value(clientId),
          montant: montantPayeInitial,
          modePaiement: modePaiementInitial,
          userId: userId,
          numeroRecu: Value(numeroRecu),
        ));
      }

      // Crée la dette client si la facture n'est pas totalement payée.
      if (clientId != null && resteAPayer > 0) {
        await db.paymentsDao.createClientDebt(ClientDebtsCompanion.insert(
          clientId: clientId,
          invoiceId: invoiceId,
          montantDu: resteAPayer,
        ));
        final client = await db.clientsDao.getClientById(clientId);
        if (client != null) {
          await db.clientsDao
              .updateDette(clientId, client.detteTotale + resteAPayer);
        }
      }

      return invoiceId;
    });
  }

  /// Modifie une facture existante en trois étapes atomiques :
  ///  1. Restauration du stock (annulation des sorties de l'ancienne facture)
  ///  2. Vérification du stock pour les nouvelles quantités
  ///  3. Application des nouvelles lignes (déduction de stock + mise à jour BDD)
  @override
  Future<void> updateInvoice({
    required int invoiceId,
    int? clientId,
    required int storeId,
    required int modifieParUserId,
    required List<CartItemInput> items,
    double remiseGlobale = 0,
  }) async {
    final existante = await db.invoicesDao.getInvoiceById(invoiceId);
    if (existante == null) throw Exception('Facture introuvable');

    final anciennesLignes =
        await db.invoicesDao.getItemsForInvoice(invoiceId);

    await db.transaction(() async {
      // ÉTAPE 1 : Restauration du stock de l'ancienne facture.
      // Chaque article sorti lors de la vente originale est ré-crédité.
      for (final ancienne in anciennesLignes) {
        await db.articlesDao.adjustStock(
          articleId: ancienne.articleId,
          storeId: existante.storeId,
          delta: ancienne.quantite, // positif = réintégration au stock
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: ancienne.articleId,
          storeId: existante.storeId,
          typeMouvement: DbConstants.movementEntree,
          quantite: ancienne.quantite,
          reference: Value('CORRECTION-${existante.numero}'),
          userId: modifieParUserId,
        ));
      }

      // ÉTAPE 2 : Vérification du stock pour les nouvelles quantités.
      final quantitesParArticle = <int, double>{};
      for (final item in items) {
        quantitesParArticle[item.articleId] =
            (quantitesParArticle[item.articleId] ?? 0) + item.quantite;
      }
      for (final entry in quantitesParArticle.entries) {
        final stockDisponible = await db.articlesDao
            .getStockForArticleInStore(entry.key, storeId);
        if (stockDisponible < entry.value) {
          final article = await db.articlesDao.getArticleById(entry.key);
          throw StockInsuffisantException(
            articleNom: article?.nom ?? 'Article inconnu',
            stockDisponible: stockDisponible,
            quantiteDemandee: entry.value,
          );
        }
      }

      // ÉTAPE 3 : Application des nouvelles lignes.
      final sousTotal =
          items.fold<double>(0, (s, i) => s + i.totalLigne);
      final nouveauTotal = _calculerTotal(items, remiseGlobale);

      // Recalcul du statut de paiement en fonction du montant déjà versé.
      final montantDejaPaye = existante.montantPaye;
      String statutPaiement;
      if (montantDejaPaye >= nouveauTotal && nouveauTotal > 0) {
        statutPaiement = DbConstants.invoiceStatusPaye;
      } else if (montantDejaPaye > 0) {
        statutPaiement = DbConstants.invoiceStatusPartiel;
      } else {
        statutPaiement = DbConstants.invoiceStatusNonPaye;
      }

      await db.invoicesDao.updateInvoiceWithItems(
        invoiceId,
        InvoicesCompanion(
          clientId: Value(clientId),
          storeId: Value(storeId),
          totalHt: Value(sousTotal),
          remiseGlobale: Value(remiseGlobale),
          totalFinal: Value(nouveauTotal),
          statutPaiement: Value(statutPaiement),
          dateModification: Value(DateTime.now()),
          modifieParUserId: Value(modifieParUserId),
        ),
        items
            .map((i) => InvoiceItemsCompanion.insert(
                  invoiceId: 0,
                  articleId: i.articleId,
                  quantite: i.quantite,
                  prixUnitaire: i.prixUnitaire,
                  remisePourcentage: Value(i.remisePourcentage),
                  remiseMontant: Value(i.remiseMontant),
                  totalLigne: i.totalLigne,
                ))
            .toList(),
      );

      // Déduction du stock et mouvements de sortie pour les nouvelles lignes.
      for (final item in items) {
        await db.articlesDao.adjustStock(
          articleId: item.articleId,
          storeId: storeId,
          delta: -item.quantite,
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: item.articleId,
          storeId: storeId,
          typeMouvement: DbConstants.movementSortie,
          quantite: item.quantite,
          reference: Value('MOD-${existante.numero}'),
          userId: modifieParUserId,
        ));
      }

      // Mise à jour de la dette client si le total a changé.
      if (clientId != null) {
        final ancienReste = existante.totalFinal - montantDejaPaye;
        final nouveauReste = nouveauTotal - montantDejaPaye;
        final delta = nouveauReste - ancienReste;
        if (delta.abs() > 0.01) {
          final client = await db.clientsDao.getClientById(clientId);
          if (client != null) {
            final nouvelleDette = (client.detteTotale + delta).clamp(0.0, double.infinity);
            await db.clientsDao.updateDette(clientId, nouvelleDette);
          }
        }
      }
    });
  }

  @override
  Future<void> deleteInvoice(int id) async {
    await (db.delete(db.invoices)..where((i) => i.id.equals(id))).go();
  }
}
