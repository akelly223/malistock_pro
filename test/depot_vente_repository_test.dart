import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/depot_vente_repository_impl.dart';
import 'package:malistock_pro/data/repositories/payment_repository_impl.dart';
import 'package:malistock_pro/domain/entities/depot_vente_stat.dart';

/// Vérifie que l'Espace Dépôt-vente liste bien les titres en dépôt
/// avec leur bénéfice propre (CA HT - part reversée au fournisseur),
/// filtrable par catégorie/fournisseur, sans jamais inclure les
/// articles normaux du commerçant.
void main() {
  test('liste les titres en dépôt avec ventes et bénéfice calculés séparément',
      () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final storeId = await db
        .into(db.stores)
        .insert(StoresCompanion.insert(nom: 'Librairie'));
    final categorieId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(nom: 'Romans'));

    final auteurId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            nom: 'Auteur Test',
            estDepot: const Value(true),
            partAuteurPct: const Value(60),
          ),
        );

    final articleDepotId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-DEP',
            nom: 'Roman en dépôt',
            prixVente: 5000,
            stockTotal: const Value(7),
            categorieId: Value(categorieId),
            supplierId: Value(auteurId),
          ),
        );

    // Article normal : ne doit jamais apparaître dans cet espace.
    await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'LIVRE-NORM',
            nom: 'Livre normal',
            prixVente: 1000,
          ),
        );

    final docId = await db.into(db.commercialDocuments).insert(
          CommercialDocumentsCompanion.insert(
            numero: 'FAC-2026-0001',
            type: 'facture',
            statut: const Value('valide'),
            storeId: storeId,
            dateDocument: DateTime.now(),
            totalHt: const Value(15000),
            totalTva: const Value(0),
            totalTtc: const Value(15000),
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

    final repo = DepotVenteRepositoryImpl(db, PaymentRepositoryImpl(db));
    final stats = await repo.getDepotArticlesStats(periode: DepotVentePeriode.tout);

    expect(stats, hasLength(1));
    final stat = stats.single;
    expect(stat.nom, 'Roman en dépôt');
    expect(stat.categorieNom, 'Romans');
    expect(stat.supplierNom, 'Auteur Test');
    expect(stat.quantiteVendue, 3);
    expect(stat.caHt, 15000);
    expect(stat.partReversee, 9000); // 15000 * 60%
    expect(stat.beneficeLibrairie, 6000); // 15000 - 9000

    // Filtre par catégorie inexistante : liste vide.
    final filtreCategorie = await repo.getDepotArticlesStats(
      periode: DepotVentePeriode.tout,
      categorieId: categorieId + 999,
    );
    expect(filtreCategorie, isEmpty);

    // Filtre par fournisseur correct : toujours présent.
    final filtreFournisseur = await repo.getDepotArticlesStats(
      periode: DepotVentePeriode.tout,
      supplierId: auteurId,
    );
    expect(filtreFournisseur, hasLength(1));
  });
}
