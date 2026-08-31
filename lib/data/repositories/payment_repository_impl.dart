import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/payments_table.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/client_debt.dart';
import '../../domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final AppDatabase db;

  PaymentRepositoryImpl(this.db);

  PaymentEntity _toEntity(Payment p) => PaymentEntity(
        id: p.id,
        invoiceId: p.invoiceId,
        clientId: p.clientId,
        montant: p.montant,
        modePaiement: p.modePaiement,
        datePaiement: p.datePaiement,
        userId: p.userId,
        numeroRecu: p.numeroRecu,
      );

  @override
  Future<List<PaymentEntity>> getAllPayments() async {
    final list = await db.paymentsDao.getAllPayments();
    return list.map(_toEntity).toList();
  }

  @override
  Future<List<PaymentEntity>> getPaymentsForInvoice(int invoiceId) async {
    final list = await db.paymentsDao.getPaymentsForInvoice(invoiceId);
    return list.map(_toEntity).toList();
  }

  @override
  Future<List<PaymentEntity>> getPaymentsForClient(int clientId) async {
    final list = await db.paymentsDao.getPaymentsForClient(clientId);
    return list.map(_toEntity).toList();
  }

  /// Enregistre un paiement sur une facture précise : met à jour le
  /// montant payé de la facture, recalcule son statut, et réduit la
  /// dette client du même montant si une dette existe pour cette
  /// facture.
  @override
  Future<int> registerPaymentForInvoice({
    required int invoiceId,
    required double montant,
    required String modePaiement,
    required int userId,
  }) async {
    return db.transaction(() async {
      final invoice = await db.invoicesDao.getInvoiceById(invoiceId);
      if (invoice == null) throw Exception('Facture introuvable');

      final numeroRecu =
          await db.documentCountersDao.genererProchainNumero('REC');
      final paymentId = await db.paymentsDao.createPayment(
        PaymentsCompanion.insert(
          invoiceId: Value(invoiceId),
          clientId: Value(invoice.clientId),
          montant: montant,
          modePaiement: modePaiement,
          userId: userId,
          numeroRecu: Value(numeroRecu),
        ),
      );

      final nouveauMontantPaye = invoice.montantPaye + montant;
      await db.invoicesDao.updateMontantPaye(
        invoiceId,
        nouveauMontantPaye,
        invoice.totalFinal,
      );

      // Réduit la dette client associée à cette facture si elle existe.
      if (invoice.clientId != null) {
        final dettes = await db.paymentsDao.getDebtsForClient(invoice.clientId!);
        final detteFacture =
            dettes.where((d) => d.invoiceId == invoiceId).toList();
        double restantAAppliquer = montant;
        for (final dette in detteFacture) {
          if (restantAAppliquer <= 0) break;
          final nouveauMontant = dette.montantDu - restantAAppliquer;
          restantAAppliquer =
              nouveauMontant < 0 ? -nouveauMontant : 0;
          await db.paymentsDao.updateDebtAmount(
            dette.id,
            nouveauMontant < 0 ? 0 : nouveauMontant,
          );
        }

        final client = await db.clientsDao.getClientById(invoice.clientId!);
        if (client != null) {
          final nouvelleDette = client.detteTotale - montant;
          await db.clientsDao
              .updateDette(invoice.clientId!, nouvelleDette < 0 ? 0 : nouvelleDette);
        }
      }

      return paymentId;
    });
  }

  /// Règlement global de dette, unifié V1+V2 : répartit le montant reçu
  /// en FIFO (plus ancien d'abord) sur les ventes impayées du client,
  /// qu'elles viennent de `commercial_documents` (V2, "Nouvelle vente")
  /// ou des anciennes `invoices` non migrées (V1) — même déduplication
  /// par `numero` que `ClientRepositoryImpl._dettesUnifiees`. Pour la
  /// part V1, réutilise [registerPaymentForInvoice] telle quelle (met à
  /// jour `client_debts` et `clients.dette_totale` sans rien changer à
  /// son comportement existant).
  @override
  Future<int> registerPaymentForClientDebt({
    required int clientId,
    required double montant,
    required String modePaiement,
    required int userId,
  }) async {
    return db.transaction(() async {
      final docsV2 = await db.customSelect(
        '''
        SELECT id, date_creation FROM commercial_documents
        WHERE client_id = ? AND type IN ('facture', 'facture_comptabilisee')
          AND statut != 'annule' AND montant_paye < total_ttc
        ''',
        variables: [Variable.withInt(clientId)],
      ).get();

      final docsV1 = await db.customSelect(
        '''
        SELECT i.id, i.date_creation FROM invoices i
        WHERE i.client_id = ? AND i.montant_paye < i.total_final
          AND NOT EXISTS (
            SELECT 1 FROM commercial_documents cd WHERE cd.numero = i.numero
          )
        ''',
        variables: [Variable.withInt(clientId)],
      ).get();

      // FIFO tous types de vente confondus : plus ancien d'abord.
      final items = [
        for (final r in docsV2)
          (
            source: 'v2',
            id: r.data['id'] as int,
            date: r.data['date_creation'] as int,
          ),
        for (final r in docsV1)
          (
            source: 'v1',
            id: r.data['id'] as int,
            date: r.data['date_creation'] as int,
          ),
      ]..sort((a, b) => a.date.compareTo(b.date));

      int dernierPaymentId = 0;
      double restant = montant;
      for (final item in items) {
        if (restant <= 0) break;

        if (item.source == 'v2') {
          final doc = await db.commercialDocumentsDao.getParId(item.id);
          if (doc == null) continue;
          final reste = doc.totalTtc - doc.montantPaye;
          if (reste <= 0.01) continue;
          final montantApplique = restant >= reste ? reste : restant;
          final numeroRecu =
              await db.documentCountersDao.genererProchainNumero('REC');

          dernierPaymentId = await db.commercialDocumentsDao.ajouterPaiement(
            DocumentPaymentsCompanion.insert(
              documentId: doc.id,
              montant: montantApplique,
              datePaiement: DateTime.now(),
              modePaiement: Value(modePaiement),
              createdById: Value(userId),
              numeroRecu: Value(numeroRecu),
            ),
          );
          await db.commercialDocumentsDao.mettreAJourMontantPaye(
            doc.id,
            doc.montantPaye + montantApplique,
            doc.totalTtc,
          );
          restant -= montantApplique;
        } else {
          final invoice = await db.invoicesDao.getInvoiceById(item.id);
          if (invoice == null) continue;
          final reste = invoice.totalFinal - invoice.montantPaye;
          if (reste <= 0.01) continue;
          final montantApplique = restant >= reste ? reste : restant;

          dernierPaymentId = await registerPaymentForInvoice(
            invoiceId: invoice.id,
            montant: montantApplique,
            modePaiement: modePaiement,
            userId: userId,
          );
          restant -= montantApplique;
        }
      }

      return dernierPaymentId;
    });
  }

  @override
  Future<List<ClientDebtEntity>> getDebtsForClient(int clientId) async {
    final dettes = await db.paymentsDao.getDebtsForClient(clientId);
    final result = <ClientDebtEntity>[];
    for (final d in dettes) {
      final invoice = await db.invoicesDao.getInvoiceById(d.invoiceId);
      result.add(ClientDebtEntity(
        id: d.id,
        clientId: d.clientId,
        invoiceId: d.invoiceId,
        invoiceNumero: invoice?.numero,
        montantDu: d.montantDu,
        dateCreation: d.dateCreation,
        solde: d.solde,
      ));
    }
    return result;
  }

  /// Enregistre un paiement sur un achat précis : crée le reçu, met à
  /// jour le montant payé et le statut de paiement de l'achat.
  @override
  Future<int> registerPaymentForPurchase({
    required int purchaseId,
    required double montant,
    required String modePaiement,
    required int userId,
  }) async {
    return db.transaction(() async {
      final purchase = await db.purchasesDao.getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Achat introuvable');

      final numeroRecu =
          await db.documentCountersDao.genererProchainNumero('REC');
      final paymentId = await db.paymentsDao.createPayment(
        PaymentsCompanion.insert(
          purchaseId: Value(purchaseId),
          montant: montant,
          modePaiement: modePaiement,
          userId: userId,
          numeroRecu: Value(numeroRecu),
        ),
      );

      await db.purchasesDao.updateMontantPaye(
        purchaseId,
        purchase.montantPaye + montant,
        purchase.totalFinal,
      );

      return paymentId;
    });
  }

  /// Règlement global de dette fournisseur : FIFO plus ancien d'abord sur
  /// les achats impayés de ce fournisseur (source unique `purchases`,
  /// pas de V1/V2 à unifier côté achats).
  @override
  Future<int> registerPaymentForSupplierDebt({
    required int supplierId,
    required double montant,
    required String modePaiement,
    required int userId,
  }) async {
    return db.transaction(() async {
      final achatsImpayes = await (db.select(db.purchases)
            ..where((p) =>
                p.supplierId.equals(supplierId) &
                p.montantPaye.isSmallerThan(p.totalFinal))
            ..orderBy([(p) => OrderingTerm.asc(p.dateCreation)]))
          .get();

      int dernierPaymentId = 0;
      double restant = montant;
      for (final achat in achatsImpayes) {
        if (restant <= 0) break;
        final reste = achat.totalFinal - achat.montantPaye;
        if (reste <= 0.01) continue;
        final montantApplique = restant >= reste ? reste : restant;

        dernierPaymentId = await registerPaymentForPurchase(
          purchaseId: achat.id,
          montant: montantApplique,
          modePaiement: modePaiement,
          userId: userId,
        );
        restant -= montantApplique;
      }

      return dernierPaymentId;
    });
  }
}
