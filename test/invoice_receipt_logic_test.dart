import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/commercial_document_repository_impl.dart';
import 'package:malistock_pro/data/repositories/invoice_repository_impl.dart';
import 'package:malistock_pro/data/repositories/payment_repository_impl.dart';
import 'package:malistock_pro/data/repositories/receipt_repository_impl.dart';
import 'package:malistock_pro/domain/entities/cart_item_input.dart';
import 'package:malistock_pro/domain/entities/document_input.dart';
import 'package:malistock_pro/domain/entities/document_type.dart';

/// Vérifie les 4 cas de la logique facture/reçu demandée :
///  1. Facture payée à 100% dès la vente → aucun reçu.
///  2. Facture payée à 50% → un reçu d'acompte + une dette.
///  3. Le client revient payer une partie du reste → un 2e reçu, dette réduite.
///  4. Paiement final → dernier reçu, dette soldée, facture toujours
///     consultable avec toutes ses lignes.
///
/// Testé sur les deux chemins de création de vente : V2 (`commercial_documents`
/// via `creerVenteRapide`) et V1 (`invoices` via `createInvoice`).
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int clientId;
  late int articleId;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Boutique principale'),
        );
    userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Vendeur',
            login: 'vendeur',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    clientId = await db.into(db.clients).insert(
          ClientsCompanion.insert(nom: 'Client Test'),
        );
    articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'ART1',
            nom: 'Article Test',
            prixVente: 10000,
            prixAchat: const Value(6000),
            stockTotal: const Value(100),
            stockMinimum: const Value(5),
          ),
        );
    await db.into(db.articleStocks).insert(
          ArticleStocksCompanion.insert(
            articleId: articleId,
            storeId: storeId,
            quantite: const Value(100),
          ),
        );
  });

  tearDown(() => db.close());

  group('V2 — vente comptoir (commercial_documents)', () {
    late CommercialDocumentRepositoryImpl repo;
    late ReceiptRepositoryImpl receiptRepo;

    setUp(() {
      repo = CommercialDocumentRepositoryImpl(db);
      receiptRepo = ReceiptRepositoryImpl(db);
    });

    DocumentInput inputPourMontant(double total) => DocumentInput(
          type: DocumentType.facture,
          storeId: storeId,
          clientId: clientId,
          dateDocument: DateTime.now(),
          lignes: [
            DocumentLigneInput(
              articleId: articleId,
              articleCode: 'ART1',
              articleNom: 'Article Test',
              quantite: total / 10000,
              prixUnitaireHt: 10000,
              tauxTva: 0,
            ),
          ],
          createdById: userId,
          createdByNom: 'Vendeur',
        );

    test('Cas 1 — payée à 100% dès la vente : aucun reçu', () async {
      final docId = await repo.creerVenteRapide(
        inputPourMontant(100000),
        montantPayeInitial: 100000,
        modePaiementInitial: 'especes',
        userId: userId,
        userNom: 'Vendeur',
      );

      final doc = await repo.getParId(docId);
      expect(doc!.statutPaiement, 'paye');
      expect(doc.montantPaye, 100000);
      expect(doc.paiements, isEmpty,
          reason: 'la facture suffit comme preuve, aucun reçu ne doit être créé');

      final recus = await receiptRepo.getAllReceipts();
      expect(recus, isEmpty);
    });

    test('Cas 2, 3, 4 — acompte puis règlements successifs jusqu\'au solde',
        () async {
      // Cas 2 : facture de 100 000, acompte de 65 000 à la vente.
      final docId = await repo.creerVenteRapide(
        inputPourMontant(100000),
        montantPayeInitial: 65000,
        modePaiementInitial: 'especes',
        userId: userId,
        userNom: 'Vendeur',
      );

      var doc = await repo.getParId(docId);
      expect(doc!.statutPaiement, 'partiel');
      expect(doc.montantPaye, 65000);
      expect(doc.resteAPayer, 35000);
      expect(doc.paiements, hasLength(1),
          reason: 'un reçu d\'acompte doit être créé pour le paiement partiel');

      var recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(1));
      expect(recus.first.montantRecu, 65000);
      expect(recus.first.montantPayeAvant, 0);
      expect(recus.first.factureSoldee, isFalse);
      final premierNumero = recus.first.numeroRecu;

      // Cas 3 : le client revient payer 20 000.
      await repo.enregistrerPaiement(
        docId,
        DocumentPaiementInput(
          montant: 20000,
          datePaiement: DateTime.now(),
          modePaiement: 'especes',
        ),
        userId: userId,
        userNom: 'Vendeur',
      );

      doc = await repo.getParId(docId);
      expect(doc!.statutPaiement, 'partiel');
      expect(doc.montantPaye, 85000);
      expect(doc.resteAPayer, 15000);
      expect(doc.paiements, hasLength(2),
          reason: 'un 2e reçu doit être créé pour ce règlement');
      // La facture (lignes, total) reste inchangée par le règlement.
      expect(doc.totalTtc, 100000);
      expect(doc.lignes, hasLength(1));

      recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(2));
      final deuxiemeRecu = recus.firstWhere((r) => r.montantRecu == 20000);
      expect(deuxiemeRecu.montantPayeAvant, 65000);
      expect(deuxiemeRecu.numeroRecu == premierNumero, isFalse);

      // Cas 4 : paiement final de 15 000 → dette soldée.
      await repo.enregistrerPaiement(
        docId,
        DocumentPaiementInput(
          montant: 15000,
          datePaiement: DateTime.now(),
          modePaiement: 'especes',
        ),
        userId: userId,
        userNom: 'Vendeur',
      );

      doc = await repo.getParId(docId);
      expect(doc!.statutPaiement, 'paye');
      expect(doc.montantPaye, 100000);
      expect(doc.resteAPayer, 0);
      expect(doc.paiements, hasLength(3),
          reason: 'le règlement final génère lui aussi un reçu');
      // La facture reste consultable avec toutes ses lignes.
      expect(doc.lignes, hasLength(1));
      expect(doc.lignes.first.articleNom, 'Article Test');

      recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(3));
      final dernierRecu = recus.firstWhere((r) => r.montantRecu == 15000);
      expect(dernierRecu.montantPayeAvant, 85000);
      expect(dernierRecu.factureSoldee, isTrue);
    });
  });

  group('V1 — vente directe (invoices, écran Historique)', () {
    late InvoiceRepositoryImpl repo;
    late PaymentRepositoryImpl paymentRepo;
    late ReceiptRepositoryImpl receiptRepo;

    setUp(() {
      repo = InvoiceRepositoryImpl(db);
      paymentRepo = PaymentRepositoryImpl(db);
      receiptRepo = ReceiptRepositoryImpl(db);
    });

    List<CartItemInput> itemsPourMontant(double total) => [
          CartItemInput(
            articleId: articleId,
            articleNom: 'Article Test',
            quantite: total / 10000,
            prixUnitaire: 10000,
          ),
        ];

    test('Cas 1 — payée à 100% dès la vente : aucun reçu', () async {
      final invoiceId = await repo.createInvoice(
        clientId: clientId,
        storeId: storeId,
        userId: userId,
        items: itemsPourMontant(25000),
        montantPayeInitial: 25000,
        modePaiementInitial: 'especes',
      );

      final invoice = await repo.getInvoiceById(invoiceId);
      expect(invoice!.statutPaiement, 'paye');
      expect(invoice.resteAPayer, 0);

      final paiements = await paymentRepo.getPaymentsForInvoice(invoiceId);
      expect(paiements, isEmpty,
          reason: 'la facture suffit comme preuve, aucun reçu ne doit être créé');

      final recus = await receiptRepo.getAllReceipts();
      expect(recus, isEmpty);
    });

    test('Cas 2, 3, 4 — acompte puis règlements successifs jusqu\'au solde',
        () async {
      // Cas 2 : facture de 100 000, acompte de 65 000 à la vente.
      final invoiceId = await repo.createInvoice(
        clientId: clientId,
        storeId: storeId,
        userId: userId,
        items: itemsPourMontant(100000),
        montantPayeInitial: 65000,
        modePaiementInitial: 'especes',
      );

      var invoice = await repo.getInvoiceById(invoiceId);
      expect(invoice!.statutPaiement, 'partiel');
      expect(invoice.resteAPayer, 35000);

      var paiements = await paymentRepo.getPaymentsForInvoice(invoiceId);
      expect(paiements, hasLength(1),
          reason: 'un reçu d\'acompte doit être créé pour le paiement partiel');
      expect(paiements.first.numeroRecu != null, isTrue);

      var recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(1));
      expect(recus.first.montantRecu, 65000);
      expect(recus.first.factureSoldee, isFalse);

      // Cas 3 : le client revient payer 20 000.
      await paymentRepo.registerPaymentForInvoice(
        invoiceId: invoiceId,
        montant: 20000,
        modePaiement: 'especes',
        userId: userId,
      );

      invoice = await repo.getInvoiceById(invoiceId);
      expect(invoice!.statutPaiement, 'partiel');
      expect(invoice.resteAPayer, 15000);
      // La facture (lignes, total) reste inchangée par le règlement.
      expect(invoice.totalFinal, 100000);
      expect(invoice.items, hasLength(1));

      paiements = await paymentRepo.getPaymentsForInvoice(invoiceId);
      expect(paiements, hasLength(2),
          reason: 'un 2e reçu doit être créé pour ce règlement');

      recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(2));

      // Cas 4 : paiement final de 15 000 → dette soldée.
      await paymentRepo.registerPaymentForInvoice(
        invoiceId: invoiceId,
        montant: 15000,
        modePaiement: 'especes',
        userId: userId,
      );

      invoice = await repo.getInvoiceById(invoiceId);
      expect(invoice!.statutPaiement, 'paye');
      expect(invoice.resteAPayer, 0);
      // La facture reste consultable avec toutes ses lignes.
      expect(invoice.items, hasLength(1));
      expect(invoice.items.first.articleNom, 'Article Test');

      paiements = await paymentRepo.getPaymentsForInvoice(invoiceId);
      expect(paiements, hasLength(3),
          reason: 'le règlement final génère lui aussi un reçu');

      recus = await receiptRepo.getAllReceipts();
      expect(recus, hasLength(3));
      final dernierRecu = recus.firstWhere((r) => r.montantRecu == 15000);
      expect(dernierRecu.factureSoldee, isTrue);
    });
  });
}
