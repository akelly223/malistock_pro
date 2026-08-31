import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/commercial_document_repository_impl.dart';
import 'package:malistock_pro/data/repositories/depot_vente_repository_impl.dart';
import 'package:malistock_pro/data/repositories/payment_repository_impl.dart';
import 'package:malistock_pro/domain/entities/depot_vente_reglement.dart';
import 'package:malistock_pro/domain/entities/document_input.dart';
import 'package:malistock_pro/domain/entities/document_type.dart';

/// Scénario imposé par la demande utilisateur du 2026-08-17 (§13) : un
/// auteur TEST avec 3 titres vendus sur plusieurs jours (3+2+2 = 7
/// livres), le règlement en un clic, la disparition de « à régler »,
/// la conservation dans l'historique, et la non-interférence avec le
/// stock et les ventes normales. Les ventes passent par le vrai chemin
/// V2 (`creerVenteRapide`) pour exercer la génération réelle des achats
/// fantômes `DEP-...`, pas une insertion directe en base.
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int auteurId;
  late int articleAId;
  late int articleBId;
  late int articleCId;
  late int articleNormalId;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    storeId =
        await db.into(db.stores).insert(StoresCompanion.insert(nom: 'Librairie'));
    userId = await db.into(db.users).insert(UsersCompanion.insert(
          nom: 'Libraire',
          login: 'libraire',
          motDePasseHash: 'x',
          role: 'admin',
        ));
    auteurId = await db.into(db.suppliers).insert(SuppliersCompanion.insert(
          nom: 'TEST',
          estDepot: const Value(true),
          partAuteurPct: const Value(50),
        ));

    articleAId = await db.into(db.articles).insert(ArticlesCompanion.insert(
          code: 'LIVRE-A',
          nom: 'Livre A',
          prixVente: 5000,
          supplierId: Value(auteurId),
        ));
    articleBId = await db.into(db.articles).insert(ArticlesCompanion.insert(
          code: 'LIVRE-B',
          nom: 'Livre B',
          prixVente: 4000,
          supplierId: Value(auteurId),
        ));
    articleCId = await db.into(db.articles).insert(ArticlesCompanion.insert(
          code: 'LIVRE-C',
          nom: 'Livre C',
          prixVente: 3000,
          supplierId: Value(auteurId),
        ));
    articleNormalId = await db.into(db.articles).insert(ArticlesCompanion.insert(
          code: 'LIVRE-MALISTOCK',
          nom: 'Livre MaliStock Pro',
          prixVente: 2000,
        ));

    for (final id in [articleAId, articleBId, articleCId, articleNormalId]) {
      await db.into(db.articleStocks).insert(ArticleStocksCompanion.insert(
            articleId: id,
            storeId: storeId,
            quantite: const Value(20),
          ));
    }
  });

  tearDown(() => db.close());

  test(
      'scénario TEST §13 : 3+2+2 livres vendus, à régler, marquer comme '
      'réglé, historique, stock et ventes normales intacts', () async {
    final docRepo = CommercialDocumentRepositoryImpl(db);
    final depotRepo = DepotVenteRepositoryImpl(db, PaymentRepositoryImpl(db));

    // Jour 1 : vente mélangée — Livre A (dépôt) + Livre MaliStock Pro
    // (normal) dans le MÊME document, pour vérifier l'exclusion au
    // niveau de la ligne, pas du document (§9).
    await docRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleAId,
            articleCode: 'LIVRE-A',
            articleNom: 'Livre A',
            quantite: 3,
            prixUnitaireHt: 5000,
            tauxTva: 0,
          ),
          DocumentLigneInput(
            articleId: articleNormalId,
            articleCode: 'LIVRE-MALISTOCK',
            articleNom: 'Livre MaliStock Pro',
            quantite: 1,
            prixUnitaireHt: 2000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 0,
      userId: userId,
      userNom: 'Libraire',
    );

    // Jour 2 : Livre B.
    await docRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleBId,
            articleCode: 'LIVRE-B',
            articleNom: 'Livre B',
            quantite: 2,
            prixUnitaireHt: 4000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 0,
      userId: userId,
      userNom: 'Libraire',
    );

    // Jour 4 : Livre C.
    await docRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleCId,
            articleCode: 'LIVRE-C',
            articleNom: 'Livre C',
            quantite: 2,
            prixUnitaireHt: 3000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 0,
      userId: userId,
      userNom: 'Libraire',
    );

    // ── « À régler » : les 7 livres de TEST, montants à 50% (part
    // auteur), aucune trace du Livre MaliStock Pro ──────────────────────
    final aRegler = await depotRepo.getLignesARegler();
    expect(aRegler, hasLength(3));
    expect(aRegler.every((l) => l.supplierNom == 'TEST'), isTrue);
    expect(aRegler.any((l) => l.articleNom == 'Livre MaliStock Pro'), isFalse);

    final totalLivres =
        aRegler.fold<double>(0, (s, l) => s + l.quantiteVendue);
    final totalMontant = aRegler.fold<double>(0, (s, l) => s + l.montantDu);
    expect(totalLivres, 7); // 3 + 2 + 2
    // 50% de (3×5000 + 2×4000 + 2×3000) = 50% de 29000 = 14500.
    expect(totalMontant, 14500);

    // Stock juste après les ventes (référence pour vérifier que le
    // règlement ne le modifie pas).
    Future<double> stockDe(int articleId) async {
      final s = await (db.select(db.articleStocks)
            ..where((r) =>
                r.articleId.equals(articleId) & r.storeId.equals(storeId)))
          .getSingle();
      return s.quantite;
    }

    final stockAvantReglement = {
      articleAId: await stockDe(articleAId),
      articleBId: await stockDe(articleBId),
      articleCId: await stockDe(articleCId),
      articleNormalId: await stockDe(articleNormalId),
    };
    expect(stockAvantReglement[articleAId], 17); // 20 - 3
    expect(stockAvantReglement[articleBId], 18); // 20 - 2
    expect(stockAvantReglement[articleCId], 18); // 20 - 2
    expect(stockAvantReglement[articleNormalId], 19); // 20 - 1

    // ── Règlement : un clic « Marquer comme réglé » ──────────────────
    final avantReglement = DateTime.now().subtract(const Duration(seconds: 2));
    final reglement =
        await depotRepo.reglerFournisseur(supplierId: auteurId, userId: userId);

    expect(reglement.supplierNom, 'TEST');
    expect(reglement.quantiteLivres, 7);
    expect(reglement.montantDu, 14500);
    expect(reglement.montantPaye, 14500);
    expect(reglement.resteAPayer, 0);
    expect(reglement.statut, DepotVenteReglementStatut.regle);
    // Vente totale = part auteur ÷ 50% ; commission = le reste.
    expect(reglement.venteTotale, 29000);
    expect(reglement.commission, 14500);
    // Détail par livre conservé (§6, §11).
    expect(reglement.lignes, hasLength(3));
    expect(
        reglement.lignes.map((l) => l.articleNom).toSet(),
        {'Livre A', 'Livre B', 'Livre C'});
    // Date ET heure enregistrées automatiquement, proches de maintenant.
    expect(reglement.dateHeure.isAfter(avantReglement), isTrue);
    expect(reglement.dateHeure.isBefore(DateTime.now().add(const Duration(seconds: 2))),
        isTrue);

    // ── Disparition immédiate de « à régler » ────────────────────────
    final aReglerApres = await depotRepo.getLignesARegler();
    expect(aReglerApres, isEmpty);

    // ── Conservation permanente dans l'historique ────────────────────
    final historique = await depotRepo.getHistoriqueReglements();
    expect(historique, hasLength(1));
    expect(historique.single.supplierNom, 'TEST');
    expect(historique.single.quantiteLivres, 7);
    expect(historique.single.montantPaye, 14500);
    expect(historique.single.statut, DepotVenteReglementStatut.regle);
    expect(historique.single.lignes, hasLength(3));

    // ── Le stock n'a pas bougé : seul le paiement a changé ───────────
    expect(await stockDe(articleAId), stockAvantReglement[articleAId]);
    expect(await stockDe(articleBId), stockAvantReglement[articleBId]);
    expect(await stockDe(articleCId), stockAvantReglement[articleCId]);
    expect(await stockDe(articleNormalId), stockAvantReglement[articleNormalId]);

    // ── Les achats fantômes DEP- sont bien soldés (données conservées,
    // pas supprimées) ─────────────────────────────────────────────────
    final achatsAuteur = await (db.select(db.purchases)
          ..where((p) => p.supplierId.equals(auteurId)))
        .get();
    expect(achatsAuteur, hasLength(3));
    expect(achatsAuteur.every((a) => a.statutPaiement == 'paye'), isTrue);
    expect(achatsAuteur.every((a) => a.montantPaye == a.totalFinal), isTrue);

    // ── La vente normale (Livre MaliStock Pro) n'est affectée nulle part ─
    final achatsNormal = await (db.select(db.purchases)
          ..where((p) => p.supplierId.equals(articleNormalId)))
        .get();
    expect(achatsNormal, isEmpty);
    expect(
        historique.any((r) => r.supplierNom == 'Livre MaliStock Pro'), isFalse);
  });

  test('reglerFournisseur lève une exception si rien à régler', () async {
    final depotRepo = DepotVenteRepositoryImpl(db, PaymentRepositoryImpl(db));
    expect(
      () => depotRepo.reglerFournisseur(supplierId: auteurId, userId: userId),
      throwsException,
    );
  });

  test(
      'scénario TEST §17 : règlement partiel puis solde, statuts et '
      'historique corrects', () async {
    final docRepo = CommercialDocumentRepositoryImpl(db);
    final depotRepo = DepotVenteRepositoryImpl(db, PaymentRepositoryImpl(db));

    // Vente de 3 exemplaires du Livre A (5000 FCFA, commission 50%).
    await docRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleAId,
            articleCode: 'LIVRE-A',
            articleNom: 'Livre A',
            quantite: 3,
            prixUnitaireHt: 5000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 0,
      userId: userId,
      userNom: 'Libraire',
    );
    // Puis 2 exemplaires supplémentaires.
    await docRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime.now(),
        lignes: [
          DocumentLigneInput(
            articleId: articleAId,
            articleCode: 'LIVRE-A',
            articleNom: 'Livre A',
            quantite: 2,
            prixUnitaireHt: 5000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Libraire',
      ),
      montantPayeInitial: 0,
      userId: userId,
      userNom: 'Libraire',
    );

    // 5 livres vendus × 5000 × 50% = 12500 dus.
    final aRegler = await depotRepo.getLignesARegler();
    final totalDu = aRegler.fold<double>(0, (s, l) => s + l.montantDu);
    expect(totalDu, 12500);

    // ── Règlement partiel : 5000 sur 12500 dus ────────────────────────
    final partiel = await depotRepo.reglerFournisseur(
      supplierId: auteurId,
      montant: 5000,
      note: 'Acompte du 21/08/2026',
      userId: userId,
    );
    expect(partiel.montantDu, 12500);
    expect(partiel.montantPaye, 5000);
    expect(partiel.resteAPayer, 7500);
    expect(partiel.statut, DepotVenteReglementStatut.partiel);
    expect(partiel.note, 'Acompte du 21/08/2026');

    // Le solde restant est toujours visible dans « à régler ».
    final aReglerApresPartiel = await depotRepo.getLignesARegler();
    final resteDu =
        aReglerApresPartiel.fold<double>(0, (s, l) => s + l.montantDu);
    expect(resteDu, 7500);

    // ── Solde du reste (7500) ─────────────────────────────────────────
    final solde = await depotRepo.reglerFournisseur(
      supplierId: auteurId,
      userId: userId,
    );
    expect(solde.montantDu, 7500);
    expect(solde.montantPaye, 7500);
    expect(solde.resteAPayer, 0);
    expect(solde.statut, DepotVenteReglementStatut.regle);

    // ── Disparition de « à régler », conservation des 2 évènements ────
    expect(await depotRepo.getLignesARegler(), isEmpty);
    final historique = await depotRepo.getHistoriqueReglements();
    expect(historique, hasLength(2));
    expect(historique.map((r) => r.statut),
        containsAll([DepotVenteReglementStatut.partiel, DepotVenteReglementStatut.regle]));
  });
}
