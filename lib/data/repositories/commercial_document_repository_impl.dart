import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/document_input.dart';
import '../../domain/repositories/commercial_document_repository.dart';
import '../../domain/exceptions/document_verrouille_exception.dart';
import '../../domain/exceptions/stock_insuffisant_exception.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/tva_calculation_service.dart';
import '../../core/services/stock_impact_service.dart';
import '../../core/services/document_transformation_service.dart';

class CommercialDocumentRepositoryImpl
    implements CommercialDocumentRepository {
  final AppDatabase _db;
  final _tva = const TVACalculationService();
  final _transformRules = const DocumentTransformationService();
  late final StockImpactService _stock;

  CommercialDocumentRepositoryImpl(this._db) {
    _stock = StockImpactService(_db);
  }

  // ── Mapping Drift → Entity ────────────────────────────────────────────────

  DocumentLigneEntity _toLigneEntity(DocumentLine l) => DocumentLigneEntity(
        id: l.id,
        documentId: l.documentId,
        articleId: l.articleId,
        articleCode: l.articleCode,
        articleNom: l.articleNom,
        quantite: l.quantite,
        prixUnitaireHt: l.prixUnitaireHt,
        tauxTva: l.tauxTva,
        remiseLignePct: l.remiseLignePct,
        totalHt: l.totalHt,
        montantTva: l.montantTva,
        totalTtc: l.totalTtc,
        position: l.position,
        notesLigne: l.notesLigne,
      );

  DocumentPaiementEntity _toPaiementEntity(DocumentPayment p) =>
      DocumentPaiementEntity(
        id: p.id,
        documentId: p.documentId,
        montant: p.montant,
        datePaiement: p.datePaiement,
        modePaiement: p.modePaiement,
        reference: p.reference,
        avoirDocumentId: p.avoirDocumentId,
        createdByNom: p.createdByNom,
        dateCreation: p.dateCreation,
      );

  Future<DocumentEntity> _toEntity(CommercialDocument doc) async {
    final ligneRows =
        await _db.commercialDocumentsDao.getLignesDuDocument(doc.id);
    final paiementRows =
        await _db.commercialDocumentsDao.getPaiementsDuDocument(doc.id);

    String? clientNom;
    String? clientNif;
    if (doc.clientId != null) {
      final c = await _db.clientsDao.getClientById(doc.clientId!);
      clientNom = c?.nom;
      clientNif = c?.nif;
    }
    final store = await _db.storesDao.getStoreById(doc.storeId);

    return DocumentEntity(
      id: doc.id,
      numero: doc.numero,
      type: DocumentType.fromCode(doc.type),
      statut: DocumentStatut.fromCode(doc.statut),
      clientId: doc.clientId,
      clientNom: clientNom,
      clientNif: clientNif,
      storeId: doc.storeId,
      storeNom: store?.nom,
      dateDocument: doc.dateDocument,
      dateCreation: doc.dateCreation,
      dateModification: doc.dateModification,
      dateValidation: doc.dateValidation,
      dateEcheance: doc.dateEcheance,
      createdById: doc.createdById,
      createdByNom: doc.createdByNom,
      totalHt: doc.totalHt,
      totalTva: doc.totalTva,
      totalTtc: doc.totalTtc,
      remiseGlobalePct: doc.remiseGlobalePct,
      montantPaye: doc.montantPaye,
      statutPaiement: doc.statutPaiement,
      parentDocumentId: doc.parentDocumentId,
      notes: doc.notes,
      referenceExterne: doc.referenceExterne,
      conditionsReglement: doc.conditionsReglement,
      lignes: ligneRows.map(_toLigneEntity).toList(),
      paiements: paiementRows.map(_toPaiementEntity).toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DocumentLinesCompanion _ligneInputToCompanion(
    DocumentLigneInput input,
    int position,
  ) {
    final totaux = _tva.calculerLigne(
      quantite: input.quantite,
      prixUnitaireHt: input.prixUnitaireHt,
      tauxTva: input.tauxTva,
      remiseLignePct: input.remiseLignePct,
    );
    return DocumentLinesCompanion.insert(
      documentId: 0, // remplacé par le DAO
      articleId: input.articleId,
      articleCode: input.articleCode,
      articleNom: input.articleNom,
      quantite: input.quantite,
      prixUnitaireHt: input.prixUnitaireHt,
      tauxTva: Value(input.tauxTva),
      remiseLignePct: Value(input.remiseLignePct),
      totalHt: Value(totaux.totalHt),
      montantTva: Value(totaux.montantTva),
      totalTtc: Value(totaux.totalTtc),
      position: Value(position),
      notesLigne: Value(input.notesLigne),
    );
  }

  /// Calcule les totaux du document à partir de ses lignes et de la remise.
  ({double ht, double tva, double ttc}) _calculerTotaux(
    List<DocumentLigneInput> lignes,
    double remiseGlobalePct,
  ) {
    final totauxLignes =
        lignes.map((l) => _tva.calculerLigne(
              quantite: l.quantite,
              prixUnitaireHt: l.prixUnitaireHt,
              tauxTva: l.tauxTva,
              remiseLignePct: l.remiseLignePct,
            ));
    final doc = _tva.calculerDocument(
      lignes: totauxLignes.toList(),
      remiseGlobalePct: remiseGlobalePct,
    );
    return (ht: doc.totalHt, tva: doc.totalTva, ttc: doc.totalTtc);
  }

  Future<void> _ajouterHistorique({
    required int documentId,
    required String action,
    String? ancienStatut,
    String? nouveauStatut,
    String? description,
    required int userId,
    required String userNom,
  }) =>
      _db.commercialDocumentsDao.ajouterHistorique(
        DocumentHistoriesCompanion.insert(
          documentId: documentId,
          action: action,
          ancienStatut: Value(ancienStatut),
          nouveauStatut: Value(nouveauStatut),
          description: Value(description),
          userId: Value(userId),
          userNom: Value(userNom),
        ),
      );

  // ── Lecture ───────────────────────────────────────────────────────────────

  @override
  Future<List<DocumentEntity>> getParType(DocumentType type) async {
    final rows = await _db.commercialDocumentsDao.getParType(type.code);
    final result = <DocumentEntity>[];
    for (final r in rows) { result.add(await _toEntity(r)); }
    return result;
  }

  @override
  Future<List<DocumentEntity>> getVentes() async {
    final rows = await _db.commercialDocumentsDao.getVentes();
    final result = <DocumentEntity>[];
    for (final r in rows) { result.add(await _toEntity(r)); }
    return result;
  }

  @override
  Future<List<DocumentEntity>> getParTypeEtStatut(
      DocumentType type, DocumentStatut statut) async {
    final rows = await _db.commercialDocumentsDao
        .getParTypeEtStatut(type.code, statut.code);
    final result = <DocumentEntity>[];
    for (final r in rows) { result.add(await _toEntity(r)); }
    return result;
  }

  @override
  Future<DocumentEntity?> getParId(int id) async {
    final row = await _db.commercialDocumentsDao.getParId(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<DocumentEntity>> getParClient(int clientId) async {
    final rows = await _db.commercialDocumentsDao.getParClient(clientId);
    final result = <DocumentEntity>[];
    for (final r in rows) { result.add(await _toEntity(r)); }
    return result;
  }

  @override
  Future<List<DocumentEntity>> getEnfants(int parentId) async {
    final rows = await _db.commercialDocumentsDao.getEnfants(parentId);
    final result = <DocumentEntity>[];
    for (final r in rows) { result.add(await _toEntity(r)); }
    return result;
  }

  // ── Création ──────────────────────────────────────────────────────────────

  @override
  Future<int> creer(DocumentInput input) async {
    return _db.transaction(() async {
      final numero = await _db.commercialDocumentsDao
          .genererProchainNumero(input.type.prefixeNumero);
      final totaux =
          _calculerTotaux(input.lignes, input.remiseGlobalePct);

      final docId = await _db.commercialDocumentsDao.creerAvecLignes(
        CommercialDocumentsCompanion.insert(
          numero: numero,
          type: input.type.code,
          storeId: input.storeId,
          clientId: Value(input.clientId),
          dateDocument: input.dateDocument,
          createdById: Value(input.createdById),
          createdByNom: Value(input.createdByNom),
          totalHt: Value(totaux.ht),
          totalTva: Value(totaux.tva),
          totalTtc: Value(totaux.ttc),
          remiseGlobalePct: Value(input.remiseGlobalePct),
          parentDocumentId: Value(input.parentDocumentId),
          notes: Value(input.notes),
          referenceExterne: Value(input.referenceExterne),
          conditionsReglement: Value(input.conditionsReglement),
        ),
        input.lignes
            .asMap()
            .entries
            .map((e) => _ligneInputToCompanion(e.value, e.key))
            .toList(),
      );

      if (input.createdById != null) {
        await _ajouterHistorique(
          documentId: docId,
          action: 'cree',
          nouveauStatut: DocumentStatut.brouillon.code,
          description: '${input.type.libelle} $numero créé',
          userId: input.createdById!,
          userNom: input.createdByNom ?? '',
        );
      }
      return docId;
    });
  }

  /// Vente comptoir : crée le document déjà validé, décrémente le stock
  /// et enregistre le paiement initial en une seule transaction. Voir
  /// la documentation de l'interface pour les règles de non-régression
  /// (chaîne documentaire, double décrément).
  @override
  Future<int> creerVenteRapide(
    DocumentInput input, {
    required double montantPayeInitial,
    String? modePaiementInitial,
    required int userId,
    required String userNom,
  }) async {
    return _db.transaction(() async {
      // Vérifie la disponibilité du stock pour chaque article avant toute
      // écriture, en regroupant les quantités par article (cas où le même
      // article apparaît sur plusieurs lignes).
      final quantitesParArticle = <int, double>{};
      for (final ligne in input.lignes) {
        quantitesParArticle[ligne.articleId] =
            (quantitesParArticle[ligne.articleId] ?? 0) + ligne.quantite;
      }
      for (final entry in quantitesParArticle.entries) {
        final stockDisponible = await _db.articlesDao
            .getStockForArticleInStore(entry.key, input.storeId);
        if (stockDisponible < entry.value) {
          final ligne =
              input.lignes.firstWhere((l) => l.articleId == entry.key);
          throw StockInsuffisantException(
            articleNom: ligne.articleNom,
            stockDisponible: stockDisponible,
            quantiteDemandee: entry.value,
          );
        }
      }

      final numero = await _db.commercialDocumentsDao
          .genererProchainNumero(input.type.prefixeNumero);
      final totaux = _calculerTotaux(input.lignes, input.remiseGlobalePct);
      final now = DateTime.now();

      final docId = await _db.commercialDocumentsDao.creerAvecLignes(
        CommercialDocumentsCompanion.insert(
          numero: numero,
          type: input.type.code,
          storeId: input.storeId,
          clientId: Value(input.clientId),
          dateDocument: input.dateDocument,
          createdById: Value(input.createdById),
          createdByNom: Value(input.createdByNom),
          totalHt: Value(totaux.ht),
          totalTva: Value(totaux.tva),
          totalTtc: Value(totaux.ttc),
          remiseGlobalePct: Value(input.remiseGlobalePct),
          parentDocumentId: Value(input.parentDocumentId),
          notes: Value(input.notes),
          referenceExterne: Value(input.referenceExterne),
          conditionsReglement: Value(input.conditionsReglement),
        ),
        input.lignes
            .asMap()
            .entries
            .map((e) => _ligneInputToCompanion(e.value, e.key))
            .toList(),
      );

      // Une vente comptoir n'a pas de brouillon intermédiaire : elle est
      // créée directement validée.
      await _db.commercialDocumentsDao.mettreAJourStatut(
        docId,
        DocumentStatut.valide.code,
        dateValidation: now,
      );

      await _ajouterHistorique(
        documentId: docId,
        action: 'cree',
        nouveauStatut: DocumentStatut.brouillon.code,
        description: '${input.type.libelle} $numero créé',
        userId: userId,
        userNom: userNom,
      );
      await _ajouterHistorique(
        documentId: docId,
        action: 'valide',
        ancienStatut: DocumentStatut.brouillon.code,
        nouveauStatut: DocumentStatut.valide.code,
        description: '$numero validé (vente comptoir)',
        userId: userId,
        userNom: userNom,
      );

      // Décrémente le stock immédiatement : une vente comptoir directe n'a
      // pas de Bon de Livraison en amont. Si ce document provient d'une
      // transformation (parentDocumentId non nul), le stock a déjà été
      // décrémenté par le document source — pas de double décrément.
      if (input.parentDocumentId == null) {
        for (final ligne in input.lignes) {
          await _db.articlesDao.adjustStock(
            articleId: ligne.articleId,
            storeId: input.storeId,
            delta: -ligne.quantite,
          );
          await _db.stockDao.createMovement(StockMovementsCompanion.insert(
            articleId: ligne.articleId,
            storeId: input.storeId,
            typeMouvement: 'sortie',
            quantite: ligne.quantite,
            reference: Value(numero),
            userId: userId,
          ));
        }
      }

      // Dépôt-vente : pour chaque ligne vendue dont l'article appartient
      // à un auteur en dépôt, génère un achat fournisseur "fantôme" non
      // payé représentant la part due à l'auteur. Contrairement à un
      // achat normal, on insère directement via le DAO (pas de mouvement
      // de stock ni de mise à jour de prix_achat : le stock a déjà été
      // mouvementé par la vente ci-dessus). Basé sur le total HT de la
      // ligne : la TVA est un impôt collecté pour l'État, pas une recette
      // à partager avec l'auteur.
      for (final ligne in input.lignes) {
        final article = await _db.articlesDao.getArticleById(ligne.articleId);
        if (article?.supplierId == null) continue;
        final supplier =
            await _db.suppliersDao.getSupplierById(article!.supplierId!);
        if (supplier == null || !supplier.estDepot) continue;
        if (supplier.partAuteurPct <= 0) continue;

        final totalLigneHt = _tva
            .calculerLigne(
              quantite: ligne.quantite,
              prixUnitaireHt: ligne.prixUnitaireHt,
              tauxTva: ligne.tauxTva,
              remiseLignePct: ligne.remiseLignePct,
            )
            .totalHt;
        final montantDu = totalLigneHt * supplier.partAuteurPct / 100;
        if (montantDu <= 0) continue;

        final numeroDepot =
            await _db.documentCountersDao.genererProchainNumero('DEP');
        await _db.purchasesDao.createPurchaseWithItems(
          PurchasesCompanion.insert(
            numero: numeroDepot,
            supplierId: supplier.id,
            storeId: input.storeId,
            userId: userId,
            totalHt: Value(montantDu),
            totalFinal: Value(montantDu),
            montantPaye: const Value(0),
            statutPaiement: const Value(DbConstants.invoiceStatusNonPaye),
          ),
          [
            PurchaseItemsCompanion.insert(
              purchaseId: 0,
              articleId: ligne.articleId,
              quantite: ligne.quantite,
              prixAchatUnitaire: montantDu / ligne.quantite,
              totalLigne: montantDu,
            ),
          ],
        );
      }

      // Enregistre le paiement initial (s'il y en a un) puis calcule le
      // statut de paiement (payé / partiel / non_payé). Un reçu ne se
      // justifie que si la vente reste débitrice après ce paiement : payée
      // intégralement dès la vente, la facture suffit comme preuve et
      // aucun reçu n'est créé.
      final resteApresPaiementInitial = totaux.ttc - montantPayeInitial;
      if (montantPayeInitial > 0 && modePaiementInitial != null) {
        if (resteApresPaiementInitial > 0.01) {
          final numeroRecu =
              await _db.documentCountersDao.genererProchainNumero('REC');
          await _db.commercialDocumentsDao.ajouterPaiement(
            DocumentPaymentsCompanion.insert(
              documentId: docId,
              montant: montantPayeInitial,
              datePaiement: now,
              modePaiement: Value(modePaiementInitial),
              createdById: Value(userId),
              createdByNom: Value(userNom),
              numeroRecu: Value(numeroRecu),
            ),
          );
        }
        await _ajouterHistorique(
          documentId: docId,
          action: 'paiement_ajoute',
          description: 'Paiement ${montantPayeInitial.toStringAsFixed(0)} '
              'FCFA ($modePaiementInitial)',
          userId: userId,
          userNom: userNom,
        );
      }
      await _db.commercialDocumentsDao
          .mettreAJourMontantPaye(docId, montantPayeInitial, totaux.ttc);

      return docId;
    });
  }

  @override
  Future<void> mettreAJourLignes(
    int docId,
    List<DocumentLigneInput> lignes,
    String numero,
  ) async {
    final doc = await _db.commercialDocumentsDao.getParId(docId);
    if (doc == null) throw Exception('Document $docId non trouvé');
    if (doc.statut != DocumentStatut.brouillon.code) {
      throw DocumentVerrouillException(
          numero: doc.numero, statut: doc.statut);
    }

    await _db.transaction(() async {
      // Supprime les anciennes lignes (CASCADE depuis le document)
      await _db.customStatement(
          'DELETE FROM document_lines WHERE document_id = ?', [docId]);

      // Insère les nouvelles lignes
      for (var i = 0; i < lignes.length; i++) {
        await _db.into(_db.documentLines).insert(
              _ligneInputToCompanion(lignes[i], i)
                  .copyWith(documentId: Value(docId)),
            );
      }

      // Recalcule les totaux
      final totaux = _calculerTotaux(lignes, doc.remiseGlobalePct);
      await _db.commercialDocumentsDao.mettreAJourTotaux(
        docId,
        totalHt: totaux.ht,
        totalTva: totaux.tva,
        totalTtc: totaux.ttc,
      );
    });
  }

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  @override
  Future<void> valider(int id,
      {required int userId, required String userNom}) async {
    final row = await _db.commercialDocumentsDao.getParId(id);
    if (row == null) throw Exception('Document $id non trouvé');
    if (row.statut != DocumentStatut.brouillon.code) {
      throw DocumentVerrouillException(
          numero: row.numero, statut: row.statut);
    }

    await _db.transaction(() async {
      final now = DateTime.now();
      await _db.commercialDocumentsDao.mettreAJourStatut(
        id,
        DocumentStatut.valide.code,
        dateValidation: now,
      );

      await _ajouterHistorique(
        documentId: id,
        action: 'valide',
        ancienStatut: DocumentStatut.brouillon.code,
        nouveauStatut: DocumentStatut.valide.code,
        description: '${row.numero} validé',
        userId: userId,
        userNom: userNom,
      );

      // Impact stock pour BL et BR — dans la même transaction.
      final type = DocumentType.fromCode(row.type);
      if (type.impacteStockValidation) {
        final entity = await _toEntity(row);
        if (type.estSortieStock) {
          await _stock.appliquerSortieBonLivraison(entity, userId);
        } else {
          await _stock.appliquerEntreeBonRetour(entity, userId);
        }
      }
    });
  }

  @override
  Future<void> annuler(int id,
      {required int userId,
      required String userNom,
      required String motif}) async {
    final row = await _db.commercialDocumentsDao.getParId(id);
    if (row == null) throw Exception('Document $id non trouvé');

    await _db.transaction(() async {
      // Si BL validé annulé → reverse le stock.
      final type = DocumentType.fromCode(row.type);
      if (row.statut == DocumentStatut.valide.code &&
          type.impacteStockValidation) {
        final entity = await _toEntity(row);
        if (type.estSortieStock) {
          await _stock.reverserSortieBonLivraison(entity, userId);
        }
        // BR annulé avant de créer un avoir : pas de reverse (rare)
      }

      await _db.commercialDocumentsDao.mettreAJourStatut(
          id, DocumentStatut.annule.code);

      await _ajouterHistorique(
        documentId: id,
        action: 'annule',
        ancienStatut: row.statut,
        nouveauStatut: DocumentStatut.annule.code,
        description: 'Annulé — $motif',
        userId: userId,
        userNom: userNom,
      );
    });
  }

  @override
  Future<void> comptabiliser(int id,
      {required int userId, required String userNom}) async {
    final row = await _db.commercialDocumentsDao.getParId(id);
    if (row == null) throw Exception('Document $id non trouvé');

    final type = DocumentType.fromCode(row.type);
    if (type != DocumentType.facture ||
        row.statut != DocumentStatut.valide.code) {
      throw Exception(
          'Seule une facture validée peut être comptabilisée');
    }

    await _db.transaction(() async {
      // Changement de TYPE uniquement (pas de statut) : la facture
      // comptabilisée reste le même document — numéro, montant payé,
      // paiements, client et lignes ne sont pas touchés.
      await _db.commercialDocumentsDao
          .mettreAJourType(id, DocumentType.factureComptabilisee.code);

      await _ajouterHistorique(
        documentId: id,
        action: 'comptabilise',
        description: '${row.numero} comptabilisé',
        userId: userId,
        userNom: userNom,
      );
    });
  }

  // ── Transformation ────────────────────────────────────────────────────────

  @override
  Future<DocumentEntity> transformer({
    required int sourceId,
    required DocumentType cibleType,
    required int userId,
    required String userNom,
    Map<int, double>? quantitesParLigneId,
  }) async {
    final sourceRow = await _db.commercialDocumentsDao.getParId(sourceId);
    if (sourceRow == null) throw Exception('Document $sourceId non trouvé');

    final sourceEntity = await _toEntity(sourceRow);

    // Validation des règles métier (lève TransformationImpossibleException si KO)
    _transformRules.validerTransformation(sourceEntity, cibleType);

    return _db.transaction(() async {
      final estPartielle = _transformRules.estPartielle(
          sourceEntity, quantitesParLigneId);

      // ── Génère le numéro de la pièce cible ───────────────────────────────
      final numeroCible = await _db.commercialDocumentsDao
          .genererProchainNumero(cibleType.prefixeNumero);

      // ── Calcule les lignes cibles (avec quantités éventuellement réduites)
      final lignesCibles = sourceEntity.lignes.map((l) {
        final qte = quantitesParLigneId?[l.id] ?? l.quantite;
        final t = _tva.calculerLigne(
          quantite: qte,
          prixUnitaireHt: l.prixUnitaireHt,
          tauxTva: l.tauxTva,
          remiseLignePct: l.remiseLignePct,
        );
        return DocumentLinesCompanion.insert(
          documentId: 0,
          articleId: l.articleId,
          articleCode: l.articleCode,
          articleNom: l.articleNom,
          quantite: qte,
          prixUnitaireHt: l.prixUnitaireHt,
          tauxTva: Value(l.tauxTva),
          remiseLignePct: Value(l.remiseLignePct),
          totalHt: Value(t.totalHt),
          montantTva: Value(t.montantTva),
          totalTtc: Value(t.totalTtc),
          position: Value(l.position),
        );
      }).toList();

      // ── Totaux du document cible ──────────────────────────────────────────
      final lignesInput = sourceEntity.lignes.map((l) => DocumentLigneInput(
            articleId: l.articleId,
            articleCode: l.articleCode,
            articleNom: l.articleNom,
            quantite: quantitesParLigneId?[l.id] ?? l.quantite,
            prixUnitaireHt: l.prixUnitaireHt,
            tauxTva: l.tauxTva,
            remiseLignePct: l.remiseLignePct,
          ));
      final totaux = _calculerTotaux(
          lignesInput.toList(), sourceEntity.remiseGlobalePct);

      // ── Crée le document cible ────────────────────────────────────────────
      final cibleId = await _db.commercialDocumentsDao.creerAvecLignes(
        CommercialDocumentsCompanion.insert(
          numero: numeroCible,
          type: cibleType.code,
          statut: Value(DocumentStatut.brouillon.code),
          clientId: Value(sourceEntity.clientId),
          storeId: sourceEntity.storeId,
          dateDocument: sourceEntity.dateDocument,
          createdById: Value(userId),
          createdByNom: Value(userNom),
          totalHt: Value(totaux.ht),
          totalTva: Value(totaux.tva),
          totalTtc: Value(totaux.ttc),
          remiseGlobalePct: Value(sourceEntity.remiseGlobalePct),
          parentDocumentId: Value(sourceId),
          notes: Value(sourceEntity.notes),
          referenceExterne: Value(sourceEntity.referenceExterne),
          conditionsReglement: Value(sourceEntity.conditionsReglement),
        ),
        lignesCibles,
      );

      // ── Met à jour le statut source ───────────────────────────────────────
      // Partielle : la source reste 'valide' (livraison incomplète).
      if (!estPartielle) {
        await _db.commercialDocumentsDao.mettreAJourStatut(
            sourceId, DocumentStatut.transforme.code);
      }

      // ── Historique pour les deux documents ────────────────────────────────
      await _ajouterHistorique(
        documentId: sourceId,
        action: 'transforme',
        ancienStatut: DocumentStatut.valide.code,
        nouveauStatut:
            estPartielle ? DocumentStatut.valide.code : DocumentStatut.transforme.code,
        description: 'Transformé en ${cibleType.libelle} $numeroCible'
            '${estPartielle ? ' (livraison partielle)' : ''}',
        userId: userId,
        userNom: userNom,
      );
      await _ajouterHistorique(
        documentId: cibleId,
        action: 'cree',
        nouveauStatut: DocumentStatut.brouillon.code,
        description:
            'Créé depuis ${sourceEntity.type.libelle} ${sourceEntity.numero}',
        userId: userId,
        userNom: userNom,
      );

      final cibleRow = await _db.commercialDocumentsDao.getParId(cibleId);
      return _toEntity(cibleRow!);
    });
  }

  // ── Paiements ─────────────────────────────────────────────────────────────

  @override
  Future<void> enregistrerPaiement(
    int docId,
    DocumentPaiementInput paiement, {
    required int userId,
    required String userNom,
  }) async {
    final row = await _db.commercialDocumentsDao.getParId(docId);
    if (row == null) throw Exception('Document $docId non trouvé');

    await _db.transaction(() async {
      final numeroRecu =
          await _db.documentCountersDao.genererProchainNumero('REC');
      await _db.commercialDocumentsDao.ajouterPaiement(
        DocumentPaymentsCompanion.insert(
          documentId: docId,
          montant: paiement.montant,
          datePaiement: paiement.datePaiement,
          modePaiement: Value(paiement.modePaiement),
          reference: Value(paiement.reference),
          avoirDocumentId: Value(paiement.avoirDocumentId),
          createdById: Value(userId),
          createdByNom: Value(userNom),
          numeroRecu: Value(numeroRecu),
        ),
      );

      final nouveauMontantPaye = row.montantPaye + paiement.montant;
      await _db.commercialDocumentsDao.mettreAJourMontantPaye(
          docId, nouveauMontantPaye, row.totalTtc);

      await _ajouterHistorique(
        documentId: docId,
        action: 'paiement_ajoute',
        description:
            'Paiement ${paiement.montant.toStringAsFixed(0)} FCFA '
            '(${paiement.modePaiement})',
        userId: userId,
        userNom: userNom,
      );
    });
  }

  // ── TVA ───────────────────────────────────────────────────────────────────

  @override
  Future<List<TvaRateEntity>> getTauxTvaActifs() async {
    final rows = await _db.tvaRatesDao.getActifs();
    return rows
        .map((r) => TvaRateEntity(
              id: r.id,
              taux: r.taux,
              libelle: r.libelle,
              actif: r.actif,
            ))
        .toList();
  }
}
