import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/dashboard_repository_impl.dart';
import 'package:malistock_pro/domain/repositories/dashboard_repository.dart';

/// Vérifie que le tableau de bord calcule de vraies statistiques
/// depuis SQLite, en couvrant le cas qui causait le bug historique :
/// une vente créée via l'ancien flux (`invoices`, V1) et une vente
/// créée via le flux V2 (`commercial_documents`) doivent toutes deux
/// être comptées, une seule fois chacune, quelle que soit la période
/// sélectionnée.
void main() {
  test('dashboard stats compute real numbers from seeded data, for every période',
      () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Boutique principale'),
        );
    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Admin',
            login: 'admin',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final clientId = await db.into(db.clients).insert(
          ClientsCompanion.insert(nom: 'Client Test'),
        );
    final supplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(nom: 'Fournisseur Test'),
        );
    final articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'ART1',
            nom: 'Article Test',
            prixVente: 1000,
            prixAchat: const Value(600),
            stockTotal: const Value(50),
            stockMinimum: const Value(5),
          ),
        );

    final now = DateTime.now();

    // Vente V2 (commercial_documents, type facture, validée) : 2000.
    final docId = await db.into(db.commercialDocuments).insert(
          CommercialDocumentsCompanion.insert(
            numero: 'FAC-2026-0001',
            type: 'facture',
            statut: const Value('valide'),
            clientId: Value(clientId),
            storeId: storeId,
            dateDocument: now,
            totalHt: const Value(2000),
            totalTva: const Value(0),
            totalTtc: const Value(2000),
          ),
        );
    await db.into(db.documentLines).insert(
          DocumentLinesCompanion.insert(
            documentId: docId,
            articleId: articleId,
            articleCode: 'ART1',
            articleNom: 'Article Test',
            quantite: 2,
            prixUnitaireHt: 1000,
            totalHt: const Value(2000),
            totalTtc: const Value(2000),
            position: const Value(0),
          ),
        );

    // Vente V1 (invoices) — écran "Historique", toujours accessible : 500.
    final invoiceId = await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            numero: 'FAC-2026-9999',
            clientId: Value(clientId),
            storeId: storeId,
            userId: userId,
            totalFinal: const Value(500),
          ),
        );
    await db.into(db.invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            invoiceId: invoiceId,
            articleId: articleId,
            quantite: 1,
            prixUnitaire: 500,
            totalLigne: 500,
          ),
        );

    await db.into(db.purchases).insert(
          PurchasesCompanion.insert(
            numero: 'ACH-2026-0001',
            supplierId: supplierId,
            storeId: storeId,
            userId: userId,
            totalFinal: const Value(300),
          ),
        );

    // Bon de commande fournisseur pas encore réceptionné (statut
    // 'commande', V3.0.0) : ne doit PAS être compté dans les achats du
    // tableau de bord tant que la marchandise n'est pas arrivée
    // (régression : ce montant polluait le CA achats avant correctif).
    await db.into(db.purchases).insert(
          PurchasesCompanion.insert(
            numero: 'ACH-2026-0002',
            supplierId: supplierId,
            storeId: storeId,
            userId: userId,
            totalFinal: const Value(9999),
            statut: const Value('commande'),
          ),
        );

    await db.into(db.quotes).insert(
          QuotesCompanion.insert(numero: 'DEV-2026-0001', storeId: storeId),
        );
    await db.into(db.commercialDocuments).insert(
          CommercialDocumentsCompanion.insert(
            numero: 'PRO-2026-0001',
            type: 'proforma',
            statut: const Value('valide'),
            storeId: storeId,
            dateDocument: now,
          ),
        );

    final repo = DashboardRepositoryImpl(db);

    for (final periode in DashboardPeriode.values) {
      final stats = await repo.getStats(periode);

      // Le CA cumule la vente V2 (2000) + la vente V1 (500) = 2500,
      // sans double comptage, pour chaque période testée.
      expect(stats.caPeriodeSelectionnee, 2500, reason: '$periode');
      expect(stats.nombreVentesPeriode, 2, reason: '$periode');
      expect(stats.achatsPeriodeSelectionnee, 300, reason: '$periode');
      expect(stats.nombreAchatsPeriode, 1, reason: '$periode');
      expect(stats.nombreDevisPeriode, 1, reason: '$periode');
      expect(stats.nombreProformasPeriode, 1, reason: '$periode');
    }

    final statsMois = await repo.getStats(DashboardPeriode.mois);
    expect(statsMois.ventesMois, 2500);
    expect(statsMois.nombreArticles, 1);
    expect(statsMois.valeurStock, 50 * 600);
    expect(statsMois.nombreClients, 1);
    expect(statsMois.nombreFournisseurs, 1);
    expect(statsMois.produitsLesPlusVendus, isNotEmpty);
    expect(statsMois.topClients, isNotEmpty);
    expect(statsMois.ventesParJour30.last.total, 2500);
    expect(statsMois.ventesParMois12.last.total, 2500);
  });
}
