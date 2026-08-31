import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/commercial_document_repository_impl.dart';
import 'package:malistock_pro/data/repositories/invoice_repository_impl.dart';
import 'package:malistock_pro/data/repositories/payment_repository_impl.dart';
import 'package:malistock_pro/domain/entities/cart_item_input.dart';
import 'package:malistock_pro/domain/entities/document_input.dart';
import 'package:malistock_pro/domain/entities/document_type.dart';

/// Vérifie le flux dépôt-vente auteur de bout en bout :
///  - la réception (mouvement de stock manuel) n'est pas testée ici, elle
///    ne passe par aucun code nouveau (registerMovement existant).
///  - la vente d'un article lié à un fournisseur "dépôt" génère
///    automatiquement un achat fantôme DEP-... non payé pour la part due
///    à l'auteur, sans dupliquer l'impact sur le stock.
///  - le règlement de ce solde réutilise le mécanisme fournisseur existant.
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int articleId;
  late int authorSupplierId;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Librairie'),
        );
    userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Libraire',
            login: 'libraire',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    authorSupplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            nom: 'Auteur Test',
            estDepot: const Value(true),
            partAuteurPct: const Value(60),
          ),
        );
    articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-1',
            nom: 'Roman en dépôt',
            prixVente: 5000,
            supplierId: Value(authorSupplierId),
          ),
        );
    // Réception en dépôt : mouvement d'entrée manuel, sans achat ni dette
    // (ce chemin réutilise le code existant, pas de logique nouvelle).
    await db.into(db.articleStocks).insert(
          ArticleStocksCompanion.insert(
            articleId: articleId,
            storeId: storeId,
            quantite: const Value(10),
          ),
        );
  });

  tearDown(() => db.close());

  test('la vente d\'un article en dépôt génère un achat DEP- non payé pour l\'auteur',
      () async {
    final invoiceRepo = InvoiceRepositoryImpl(db);

    final invoiceId = await invoiceRepo.createInvoice(
      storeId: storeId,
      userId: userId,
      items: [
        CartItemInput(
          articleId: articleId,
          articleNom: 'Roman en dépôt',
          quantite: 3,
          prixUnitaire: 5000,
        ),
      ],
    );

    expect(invoiceId, greaterThan(0));

    // Stock décrémenté normalement par la vente.
    final stock = await (db.select(db.articleStocks)
          ..where((s) =>
              s.articleId.equals(articleId) & s.storeId.equals(storeId)))
        .getSingle();
    expect(stock.quantite, 7); // 10 - 3

    // Un achat fantôme DEP- a été créé pour l'auteur, non payé, montant =
    // 3 × 5000 × 60% = 9000.
    final achatsAuteur = await (db.select(db.purchases)
          ..where((p) => p.supplierId.equals(authorSupplierId)))
        .get();
    expect(achatsAuteur, hasLength(1));
    final achat = achatsAuteur.single;
    expect(achat.numero, startsWith('DEP-'));
    expect(achat.totalFinal, 9000);
    expect(achat.montantPaye, 0);
    expect(achat.statutPaiement, 'non_paye');

    // Aucun mouvement de stock ni prix d'achat n'a été touché par cet
    // achat fantôme : le stock final reste 7 (déjà vérifié ci-dessus).

    // Règlement de l'auteur via le mécanisme fournisseur existant.
    final paymentRepo = PaymentRepositoryImpl(db);
    await paymentRepo.registerPaymentForSupplierDebt(
      supplierId: authorSupplierId,
      montant: 9000,
      modePaiement: 'especes',
      userId: userId,
    );

    final achatSolde = await db.purchasesDao.getPurchaseById(achat.id);
    expect(achatSolde!.montantPaye, 9000);
    expect(achatSolde.statutPaiement, 'paye');
  });

  test('un article sans fournisseur dépôt ne génère aucun achat fantôme',
      () async {
    final autreArticleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-2',
            nom: 'Livre normal',
            prixVente: 3000,
          ),
        );
    await db.into(db.articleStocks).insert(
          ArticleStocksCompanion.insert(
            articleId: autreArticleId,
            storeId: storeId,
            quantite: const Value(5),
          ),
        );

    final invoiceRepo = InvoiceRepositoryImpl(db);
    await invoiceRepo.createInvoice(
      storeId: storeId,
      userId: userId,
      items: [
        CartItemInput(
          articleId: autreArticleId,
          articleNom: 'Livre normal',
          quantite: 1,
          prixUnitaire: 3000,
        ),
      ],
    );

    final achats = await db.select(db.purchases).get();
    expect(achats, isEmpty);
  });

  test(
      'V2 (menu Ventes actuel) — la vente d\'un article en dépôt génère aussi '
      'un achat DEP- non payé pour l\'auteur', () async {
    final repo = CommercialDocumentRepositoryImpl(db);

    final docId = await repo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleId,
            articleCode: 'LIVRE-1',
            articleNom: 'Roman en dépôt',
            quantite: 3,
            prixUnitaireHt: 5000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 15000,
      modePaiementInitial: 'especes',
      userId: userId,
      userNom: 'Libraire',
    );

    expect(docId, greaterThan(0));

    final stock = await (db.select(db.articleStocks)
          ..where((s) =>
              s.articleId.equals(articleId) & s.storeId.equals(storeId)))
        .getSingle();
    expect(stock.quantite, 7); // 10 - 3

    final achatsAuteur = await (db.select(db.purchases)
          ..where((p) => p.supplierId.equals(authorSupplierId)))
        .get();
    expect(achatsAuteur, hasLength(1));
    final achat = achatsAuteur.single;
    expect(achat.numero, startsWith('DEP-'));
    expect(achat.totalFinal, 9000); // 3 × 5000 × 60%
    expect(achat.montantPaye, 0);
    expect(achat.statutPaiement, 'non_paye');
  });
}
