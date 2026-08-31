import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/depot_vente_stat.dart';
import '../../domain/entities/depot_vente_reglement.dart';
import '../../domain/repositories/depot_vente_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../core/constants/db_constants.dart';

/// Calcule les statistiques de l'Espace Dépôt-vente : titres en
/// dépôt (articles liés à un fournisseur `est_depot = 1`), avec leurs
/// ventes et bénéfice propre sur une période choisie.
///
/// Volontairement séparé de [DashboardRepositoryImpl] : ces chiffres
/// ne doivent jamais remonter dans le tableau de bord général (qui,
/// symétriquement, les exclut désormais), et inversement — voir
/// mémoire [[project_depot_vente_auteurs]].
///
/// La dette dépôt-vente n'est PAS un système à part : chaque vente
/// d'un article dépôt-vente crée déjà un achat fournisseur fantôme
/// `DEP-...` impayé (voir `CommercialDocumentRepositoryImpl.creerVenteRapide`
/// et `InvoiceRepositoryImpl`), et [PaymentRepository.registerPaymentForSupplierDebt]
/// sait déjà les solder en FIFO. `getLignesARegler`/`reglerFournisseur`
/// ne font que lire/solder ces achats fantômes ; seule
/// `depot_vente_reglements` est nouvelle, en pur journal d'historique.
class DepotVenteRepositoryImpl implements DepotVenteRepository {
  final AppDatabase db;
  final PaymentRepository paymentRepository;

  DepotVenteRepositoryImpl(this.db, this.paymentRepository);

  /// Lignes de vente unifiées V1 + V2 (mêmes règles de déduplication
  /// que le tableau de bord général), restreintes aux colonnes
  /// nécessaires à l'agrégation par article.
  static const String _lignesVente = '''
    SELECT dl.article_id AS article_id, dl.quantite AS quantite,
           dl.total_ht AS total_ht, cd.date_creation AS date_vente
    FROM document_lines dl
    JOIN commercial_documents cd ON dl.document_id = cd.id
    WHERE cd.type IN ('facture', 'facture_comptabilisee')
      AND cd.statut != 'annule'
    UNION ALL
    SELECT ii.article_id AS article_id, ii.quantite AS quantite,
           ii.total_ligne AS total_ht, i.date_creation AS date_vente
    FROM invoice_items ii
    JOIN invoices i ON ii.invoice_id = i.id
    WHERE NOT EXISTS (
      SELECT 1 FROM commercial_documents cd2 WHERE cd2.numero = i.numero
    )
  ''';

  @override
  Future<List<DepotVenteStatEntity>> getDepotArticlesStats({
    required DepotVentePeriode periode,
    int? categorieId,
    int? supplierId,
  }) async {
    final (debut, fin) = _bornesPeriode(periode);

    final variables = <Variable>[
      Variable.withInt(_epochSecondes(debut)),
      Variable.withInt(_epochSecondes(fin)),
    ];

    final filtres = StringBuffer();
    if (categorieId != null) {
      filtres.write(' AND a.categorie_id = ?');
      variables.add(Variable.withInt(categorieId));
    }
    if (supplierId != null) {
      filtres.write(' AND a.supplier_id = ?');
      variables.add(Variable.withInt(supplierId));
    }

    final rows = await db.customSelect(
      '''
      SELECT a.id AS article_id, a.code AS code, a.nom AS nom,
             a.prix_vente AS prix_vente, a.stock_total AS stock_total,
             a.categorie_id AS categorie_id, c.nom AS categorie_nom,
             a.supplier_id AS supplier_id, s.nom AS supplier_nom,
             s.part_auteur_pct AS part_auteur_pct,
             COALESCE(v.qte, 0) AS quantite_vendue,
             COALESCE(v.total_ht, 0) AS ca_ht
      FROM articles a
      JOIN suppliers s ON s.id = a.supplier_id AND s.est_depot = 1
      LEFT JOIN categories c ON c.id = a.categorie_id
      LEFT JOIN (
        SELECT article_id, SUM(quantite) AS qte, SUM(total_ht) AS total_ht
        FROM ($_lignesVente)
        WHERE date_vente >= ? AND date_vente < ?
        GROUP BY article_id
      ) v ON v.article_id = a.id
      WHERE a.actif = 1$filtres
      ORDER BY a.nom
      ''',
      variables: variables,
    ).get();

    return [
      for (final r in rows)
        DepotVenteStatEntity(
          articleId: r.data['article_id'] as int,
          code: r.data['code'] as String,
          nom: r.data['nom'] as String,
          prixVente: (r.data['prix_vente'] as num).toDouble(),
          stockTotal: (r.data['stock_total'] as num).toDouble(),
          categorieId: r.data['categorie_id'] as int?,
          categorieNom: r.data['categorie_nom'] as String?,
          supplierId: r.data['supplier_id'] as int,
          supplierNom: r.data['supplier_nom'] as String,
          partAuteurPct: (r.data['part_auteur_pct'] as num).toDouble(),
          quantiteVendue: (r.data['quantite_vendue'] as num).toDouble(),
          caHt: (r.data['ca_ht'] as num).toDouble(),
        ),
    ];
  }

  (DateTime, DateTime) _bornesPeriode(DepotVentePeriode p) {
    final now = DateTime.now();
    switch (p) {
      case DepotVentePeriode.tout:
        return (DateTime(2000, 1, 1), DateTime(now.year + 1, 1, 1));
      case DepotVentePeriode.mois:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        );
      case DepotVentePeriode.annee:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
    }
  }

  /// Drift stocke les colonnes `DateTime` en secondes unix (voir même
  /// remarque dans `DashboardRepositoryImpl`).
  int _epochSecondes(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  @override
  Future<List<DepotVenteLigneARegulerEntity>> getLignesARegler() async {
    final rows = await db.customSelect('''
      SELECT s.id AS supplier_id, s.nom AS supplier_nom,
             s.part_auteur_pct AS part_auteur_pct,
             pi.article_id AS article_id, a.code AS article_code, a.nom AS article_nom,
             SUM(pi.quantite) AS qte,
             SUM(p.total_final - p.montant_paye) AS montant
      FROM purchases p
      JOIN purchase_items pi ON pi.purchase_id = p.id
      JOIN suppliers s ON s.id = p.supplier_id AND s.est_depot = 1
      JOIN articles a ON a.id = pi.article_id
      WHERE p.numero LIKE 'DEP-%' AND p.montant_paye < p.total_final
      GROUP BY s.id, pi.article_id
      HAVING SUM(p.total_final - p.montant_paye) > 0.01
      ORDER BY s.nom, a.nom
    ''').get();

    return [
      for (final r in rows)
        DepotVenteLigneARegulerEntity(
          supplierId: r.data['supplier_id'] as int,
          supplierNom: r.data['supplier_nom'] as String,
          articleId: r.data['article_id'] as int,
          articleCode: r.data['article_code'] as String,
          articleNom: r.data['article_nom'] as String,
          quantiteVendue: (r.data['qte'] as num).toDouble(),
          montantDu: (r.data['montant'] as num).toDouble(),
          partAuteurPct: (r.data['part_auteur_pct'] as num).toDouble(),
        ),
    ];
  }

  @override
  Future<List<DepotVenteReglementEntity>> getHistoriqueReglements() async {
    final rows = await db.customSelect('''
      SELECT r.id AS id, r.supplier_id AS supplier_id, s.nom AS supplier_nom,
             r.date_heure AS date_heure, r.quantite_livres AS quantite_livres,
             r.montant_du AS montant_du, r.montant_paye AS montant_paye,
             r.statut AS statut, r.note AS note
      FROM depot_vente_reglements r
      JOIN suppliers s ON s.id = r.supplier_id
      ORDER BY r.date_heure DESC
    ''').get();

    if (rows.isEmpty) return [];

    final lignesParReglement = await _lignesParReglement(
        rows.map((r) => r.data['id'] as int).toList());

    return [
      for (final r in rows)
        DepotVenteReglementEntity(
          id: r.data['id'] as int,
          supplierId: r.data['supplier_id'] as int,
          supplierNom: r.data['supplier_nom'] as String,
          dateHeure:
              DateTime.fromMillisecondsSinceEpoch((r.data['date_heure'] as int) * 1000),
          quantiteLivres: (r.data['quantite_livres'] as num).toDouble(),
          montantDu: (r.data['montant_du'] as num).toDouble(),
          montantPaye: (r.data['montant_paye'] as num).toDouble(),
          statut: (r.data['statut'] as String) == 'partiel'
              ? DepotVenteReglementStatut.partiel
              : DepotVenteReglementStatut.regle,
          note: r.data['note'] as String?,
          lignes: lignesParReglement[r.data['id'] as int] ?? const [],
        ),
    ];
  }

  /// Charge le détail par livre de plusieurs règlements en une seule
  /// requête (pas de N+1) et les regroupe par `reglementId`.
  Future<Map<int, List<DepotVenteReglementLigneEntity>>> _lignesParReglement(
      List<int> reglementIds) async {
    if (reglementIds.isEmpty) return {};

    final rows = await (db.select(db.depotVenteReglementLignes)
          ..where((l) => l.reglementId.isIn(reglementIds)))
        .get();

    final resultat = <int, List<DepotVenteReglementLigneEntity>>{};
    for (final l in rows) {
      resultat.putIfAbsent(l.reglementId, () => []).add(
            DepotVenteReglementLigneEntity(
              articleId: l.articleId,
              articleNom: l.articleNom,
              quantite: l.quantite,
              montantVente: l.montantVente,
              montantAuteur: l.montantAuteur,
            ),
          );
    }
    return resultat;
  }

  @override
  Future<DepotVenteReglementEntity> reglerFournisseur({
    required int supplierId,
    double? montant,
    String? note,
    int? userId,
  }) {
    return db.transaction(() async {
      // Snapshot des lignes non réglées de ce fournisseur, prises depuis
      // getLignesARegler() (déjà testé) — pas de requête dupliquée.
      final toutesLesLignes = await getLignesARegler();
      final lignesFournisseur =
          toutesLesLignes.where((l) => l.supplierId == supplierId).toList();

      final totalDu =
          lignesFournisseur.fold<double>(0, (s, l) => s + l.montantDu);
      final quantiteTotale =
          lignesFournisseur.fold<double>(0, (s, l) => s + l.quantiteVendue);

      if (totalDu <= 0.01) {
        throw Exception('Rien à régler pour ce fournisseur.');
      }

      final montantAPayer = montant ?? totalDu;
      if (montantAPayer <= 0) {
        throw Exception('Le montant réglé doit être supérieur à zéro.');
      }
      if (montantAPayer > totalDu + 0.01) {
        throw Exception(
            'Le montant réglé (${montantAPayer.toStringAsFixed(0)}) '
            'dépasse le montant dû (${totalDu.toStringAsFixed(0)}).');
      }
      final montantApplique =
          montantAPayer > totalDu ? totalDu : montantAPayer;

      // Réutilise le moteur de règlement fournisseur existant (FIFO sur
      // les achats impayés) — pas de réimplémentation.
      await paymentRepository.registerPaymentForSupplierDebt(
        supplierId: supplierId,
        montant: montantApplique,
        modePaiement: DbConstants.paymentEspeces,
        userId: userId ?? 0,
      );

      final statut = montantApplique >= totalDu - 0.01
          ? DepotVenteReglementStatut.regle
          : DepotVenteReglementStatut.partiel;

      final supplier = await db.suppliersDao.getSupplierById(supplierId);
      final reglementId = await db.into(db.depotVenteReglements).insert(
            DepotVenteReglementsCompanion.insert(
              supplierId: supplierId,
              quantiteLivres: quantiteTotale,
              montantDu: Value(totalDu),
              montantPaye: montantApplique,
              statut: Value(statut == DepotVenteReglementStatut.partiel
                  ? 'partiel'
                  : 'regle'),
              note: Value(note),
              userId: Value(userId),
            ),
          );

      final lignesEntites = <DepotVenteReglementLigneEntity>[];
      for (final l in lignesFournisseur) {
        await db.into(db.depotVenteReglementLignes).insert(
              DepotVenteReglementLignesCompanion.insert(
                reglementId: reglementId,
                articleId: l.articleId,
                articleNom: l.articleNom,
                quantite: l.quantiteVendue,
                montantVente: l.venteTotale,
                montantAuteur: l.montantDu,
              ),
            );
        lignesEntites.add(DepotVenteReglementLigneEntity(
          articleId: l.articleId,
          articleNom: l.articleNom,
          quantite: l.quantiteVendue,
          montantVente: l.venteTotale,
          montantAuteur: l.montantDu,
        ));
      }

      final reglement = await (db.select(db.depotVenteReglements)
            ..where((r) => r.id.equals(reglementId)))
          .getSingle();

      return DepotVenteReglementEntity(
        id: reglement.id,
        supplierId: supplierId,
        supplierNom: supplier?.nom ?? '',
        dateHeure: reglement.dateHeure,
        quantiteLivres: quantiteTotale,
        montantDu: totalDu,
        montantPaye: montantApplique,
        statut: statut,
        note: note,
        lignes: lignesEntites,
      );
    });
  }
}
