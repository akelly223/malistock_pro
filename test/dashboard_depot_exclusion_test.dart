import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/dashboard_repository_impl.dart';
import 'package:malistock_pro/domain/repositories/dashboard_repository.dart';

/// Vérifie que le tableau de bord général ignore complètement les
/// livres en dépôt-vente (CA, bénéfice, valeur de stock, top articles),
/// même lorsqu'une même facture mélange un article en dépôt et un
/// article normal — voir demande utilisateur du 2026-08-16.
void main() {
  test('les ventes de livres en dépôt-vente n\'apparaissent pas dans les stats générales',
      () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final storeId = await db
        .into(db.stores)
        .insert(StoresCompanion.insert(nom: 'Librairie'));
    await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Admin',
            login: 'admin',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final clientId = await db
        .into(db.clients)
        .insert(ClientsCompanion.insert(nom: 'Client Test'));

    final auteurId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            nom: 'Auteur Test',
            estDepot: const Value(true),
            partAuteurPct: const Value(60),
          ),
        );

    // Article en dépôt : ne doit compter nulle part dans le tableau de
    // bord général (CA, bénéfice, valeur de stock, top articles).
    final articleDepotId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-DEP',
            nom: 'Roman en dépôt',
            prixVente: 5000,
            prixAchat: const Value(0),
            stockTotal: const Value(20),
            supplierId: Value(auteurId),
          ),
        );

    // Article normal, propriété du commerçant : doit rester compté.
    final articleNormalId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-NORM',
            nom: 'Livre normal',
            prixVente: 1000,
            prixAchat: const Value(600),
            stockTotal: const Value(20),
          ),
        );

    final now = DateTime.now();

    // Une seule facture qui mélange un article en dépôt (3 × 5000 =
    // 15000 TTC) et un article normal (2 × 1000 = 2000 TTC), pour
    // vérifier l'exclusion au niveau de la ligne, pas du document.
    final docId = await db.into(db.commercialDocuments).insert(
          CommercialDocumentsCompanion.insert(
            numero: 'FAC-2026-0001',
            type: 'facture',
            statut: const Value('valide'),
            clientId: Value(clientId),
            storeId: storeId,
            dateDocument: now,
            totalHt: const Value(17000),
            totalTva: const Value(0),
            totalTtc: const Value(17000),
          ),
        );
    await db.into(db.documentLines).insert(
          DocumentLinesCompanion.insert(
            documentId: docId,
            articleId: articleDepotId,
            articleCode: 'LIVRE-DEP',
            articleNom: 'Roman en dépôt',
            quantite: 3,
            prixUnitaireHt: 5000,
            totalHt: const Value(15000),
            totalTtc: const Value(15000),
            position: const Value(0),
          ),
        );
    await db.into(db.documentLines).insert(
          DocumentLinesCompanion.insert(
            documentId: docId,
            articleId: articleNormalId,
            articleCode: 'LIVRE-NORM',
            articleNom: 'Livre normal',
            quantite: 2,
            prixUnitaireHt: 1000,
            totalHt: const Value(2000),
            totalTtc: const Value(2000),
            position: const Value(1),
          ),
        );

    final repo = DashboardRepositoryImpl(db);
    final stats = await repo.getStats(DashboardPeriode.mois);

    // Le CA de la période ne doit compter QUE la part non-dépôt (2000),
    // pas les 15000 du livre en dépôt, même s'ils viennent de la même
    // facture.
    expect(stats.caPeriodeSelectionnee, 2000);
    expect(stats.nombreVentesPeriode, 1);

    // Bénéfice = 2000 (HT) - 600*2 (coût) = 800, uniquement sur
    // l'article normal.
    expect(stats.beneficePeriodeSelectionnee, 800);

    // L'article en dépôt ne doit pas apparaître dans le top des
    // articles vendus.
    expect(
      stats.produitsLesPlusVendus.any((p) => p.articleId == articleDepotId),
      isFalse,
    );
    expect(
      stats.produitsLesPlusVendus.any((p) => p.articleId == articleNormalId),
      isTrue,
    );

    // Le compte et la valeur de stock ne portent que sur l'article
    // normal (20 × 600 = 12000), pas sur les 20 exemplaires du livre
    // en dépôt.
    expect(stats.nombreArticles, 1);
    expect(stats.valeurStock, 12000);
  });
}
