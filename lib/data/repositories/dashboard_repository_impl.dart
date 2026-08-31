import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/article.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Calcule les statistiques du tableau de bord directement depuis
/// SQLite avec des requêtes bornées par date, pour rester rapide même
/// avec plusieurs années d'historique.
///
/// Le logiciel a deux flux de vente parallèles qui coexistent depuis
/// la migration V1→V2 (voir schemaVersion v7 dans database.dart) :
///   - `invoices` (V1, écran "Historique" toujours accessible)
///   - `commercial_documents` de type facture/facture_comptabilisee (V2,
///     flux "Nouvelle vente" mis en avant dans l'interface)
/// La migration a copié une fois pour toutes les factures V1
/// existantes vers `commercial_documents` (même `numero`, INSERT OR
/// IGNORE). Pour ne compter chaque vente qu'une seule fois, toutes les
/// requêtes ci-dessous utilisent une union : les documents V2 d'abord,
/// puis les factures V1 dont le numéro n'a PAS de contrepartie dans
/// `commercial_documents` (donc jamais migrées ni créées depuis via le
/// flux V2).
class DashboardRepositoryImpl implements DashboardRepository {
  final AppDatabase db;

  DashboardRepositoryImpl(this.db);

  /// Lignes de vente unifiées V1 + V2, une ligne par ligne de document,
  /// enrichies du statut dépôt-vente de l'article (`est_depot`) et de
  /// son coût d'achat courant. Base commune à TOUTES les statistiques
  /// du tableau de bord (CA, bénéfice, top articles, articles dormants,
  /// top clients, graphiques) : ce tableau de bord ne doit refléter que
  /// l'activité "propre" du commerçant, jamais les livres en
  /// dépôt-vente (voir [[project_depot_vente_auteurs]]) — leur CA et
  /// leur marge sont calculés séparément par l'Espace Dépôt-vente
  /// (`DepotVenteRepositoryImpl`). `doc_key` préfixe l'id par sa source
  /// (v1/v2) : les espaces d'id `invoices` et `commercial_documents`
  /// sont indépendants et pourraient sinon collisionner dans un
  /// `COUNT(DISTINCT ...)`.
  static const String _lignesVenteAvecDepot = '''
    SELECT 'v2-' || dl.document_id AS doc_key, dl.article_id AS article_id,
           dl.quantite AS quantite, dl.total_ht AS total_ht,
           dl.total_ttc AS total_ttc, cd.date_creation AS date_vente,
           cd.client_id AS client_id, a.prix_achat AS prix_achat,
           CASE WHEN s.est_depot = 1 THEN 1 ELSE 0 END AS est_depot
    FROM document_lines dl
    JOIN commercial_documents cd ON dl.document_id = cd.id
    JOIN articles a ON a.id = dl.article_id
    LEFT JOIN suppliers s ON s.id = a.supplier_id
    WHERE cd.type IN ('facture', 'facture_comptabilisee')
      AND cd.statut != 'annule'
    UNION ALL
    SELECT 'v1-' || ii.invoice_id AS doc_key, ii.article_id AS article_id,
           ii.quantite AS quantite, ii.total_ligne AS total_ht,
           ii.total_ligne AS total_ttc, i.date_creation AS date_vente,
           i.client_id AS client_id, a.prix_achat AS prix_achat,
           CASE WHEN s.est_depot = 1 THEN 1 ELSE 0 END AS est_depot
    FROM invoice_items ii
    JOIN invoices i ON ii.invoice_id = i.id
    JOIN articles a ON a.id = ii.article_id
    LEFT JOIN suppliers s ON s.id = a.supplier_id
    WHERE NOT EXISTS (
      SELECT 1 FROM commercial_documents cd2 WHERE cd2.numero = i.numero
    )
  ''';

  /// Filtre à ajouter à toute requête basée sur `articles` (alias `a`)
  /// pour exclure les livres en dépôt-vente des statistiques générales.
  static const String _excluDepotArticles =
      "(a.supplier_id IS NULL OR a.supplier_id NOT IN "
      "(SELECT id FROM suppliers WHERE est_depot = 1))";

  @override
  Future<DashboardStatsEntity> getStats(DashboardPeriode periode) async {
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final finJour = debutJour.add(const Duration(days: 1));
    final debutSemaine =
        debutJour.subtract(Duration(days: debutJour.weekday - 1));
    final finSemaine = debutSemaine.add(const Duration(days: 7));
    final debutMois = DateTime(now.year, now.month, 1);
    final finMois = DateTime(now.year, now.month + 1, 1);
    final debutAnnee = DateTime(now.year, 1, 1);
    final finAnnee = DateTime(now.year + 1, 1, 1);

    int moisPrecedent = now.month - 1;
    int anneePrecedente = now.year;
    if (moisPrecedent < 1) {
      moisPrecedent = 12;
      anneePrecedente--;
    }
    final debutMoisPrecedent = DateTime(anneePrecedente, moisPrecedent, 1);
    final finMoisPrecedent = debutMois;

    final (debutPeriode, finPeriode) = _bornesPeriode(periode, now);

    // ── Ventes : CA fixe (toujours affiché) ─────────────────────────────────

    final ventesJour = await _sommeVentes(debutJour, finJour);
    final ventesSemaine = await _sommeVentes(debutSemaine, finSemaine);
    final ventesMois = await _sommeVentes(debutMois, finMois);
    final ventesAnnee = await _sommeVentes(debutAnnee, finAnnee);
    final ventesMoisPrecedent =
        await _sommeVentes(debutMoisPrecedent, finMoisPrecedent);

    // ── CA / bénéfice / nombre de ventes pour la période sélectionnée ──────

    final ventesPeriode = await _ventesEtCompte(debutPeriode, finPeriode);
    final beneficeMoisPrecedent =
        await _beneficeSurPeriode(debutMoisPrecedent, finMoisPrecedent);
    final beneficePeriode = await _beneficeSurPeriode(debutPeriode, finPeriode);

    // ── Achats : montant + nombre pour la période sélectionnée ─────────────

    final achatsPeriode = await _achatsEtCompte(debutPeriode, finPeriode);

    // ── Documents : comptages pour la période sélectionnée ──────────────────

    final nombreDevisPeriode = await _compterSimple(
      'SELECT COUNT(*) AS n FROM quotes WHERE date_creation >= ? AND date_creation < ?',
      debutPeriode,
      finPeriode,
    );
    final nombreProformasPeriode = await _compterSimple(
      '''
      SELECT COUNT(*) AS n FROM commercial_documents
      WHERE type = 'proforma' AND statut != 'annule'
        AND date_creation >= ? AND date_creation < ?
      ''',
      debutPeriode,
      finPeriode,
    );

    // ── Dettes clients (cumulatif) ──────────────────────────────────────────

    double totalDettes = 0;
    int nbClientsAvecDette = 0;
    try {
      // Reste à payer unifié V1+V2 par client (même déduplication par
      // `numero` que `_lignesVenteAvecDepot` ci-dessous) : `clients.
      // dette_totale` n'est plus mise à jour par le flux de vente V2
      // ("Nouvelle vente"), donc ne peut plus servir de source pour ce
      // total. Volontairement PAS filtré sur le dépôt-vente : une
      // dette client reste due au commerce quel que soit l'article
      // vendu, dépôt ou non.
      final row = await db.customSelect(
        '''
        SELECT COALESCE(SUM(reste_total), 0.0) AS t, COUNT(*) AS nb FROM (
          SELECT client_id, SUM(reste) AS reste_total FROM (
            SELECT client_id, (total_ttc - montant_paye) AS reste
            FROM commercial_documents
            WHERE type IN ('facture', 'facture_comptabilisee')
              AND statut != 'annule'
              AND client_id IS NOT NULL
              AND montant_paye < total_ttc
            UNION ALL
            SELECT i.client_id, (i.total_final - i.montant_paye) AS reste
            FROM invoices i
            WHERE i.client_id IS NOT NULL
              AND i.montant_paye < i.total_final
              AND NOT EXISTS (
                SELECT 1 FROM commercial_documents cd WHERE cd.numero = i.numero
              )
          )
          GROUP BY client_id
          HAVING SUM(reste) > 0.01
        )
        ''',
      ).getSingle();
      totalDettes = (row.data['t'] as num?)?.toDouble() ?? 0;
      nbClientsAvecDette = (row.data['nb'] as int?) ?? 0;
    } catch (_) {}

    // ── Articles (cumulatif) ────────────────────────────────────────────────

    int nombreArticles = 0;
    double valeurStock = 0;
    int nombreRuptures = 0;
    int nombreAlertes = 0;
    try {
      final row = await db.customSelect('''
        SELECT
          COUNT(*) AS nb,
          COALESCE(SUM(a.stock_total * a.prix_achat), 0.0) AS valeur,
          COALESCE(SUM(CASE WHEN a.stock_total <= 0 THEN 1 ELSE 0 END), 0) AS ruptures,
          COALESCE(SUM(CASE WHEN a.stock_total > 0 AND a.stock_total <= a.stock_minimum THEN 1 ELSE 0 END), 0) AS alertes
        FROM articles a WHERE a.actif = 1 AND $_excluDepotArticles
      ''').getSingle();
      nombreArticles = (row.data['nb'] as int?) ?? 0;
      valeurStock = (row.data['valeur'] as num?)?.toDouble() ?? 0;
      nombreRuptures = (row.data['ruptures'] as int?) ?? 0;
      nombreAlertes = (row.data['alertes'] as int?) ?? 0;
    } catch (_) {}

    // ── Clients / Fournisseurs ──────────────────────────────────────────────

    final nombreClients =
        await _compterSimple('SELECT COUNT(*) AS n FROM clients', null, null);
    final nouveauxClientsPeriode = await _compterSimple(
      'SELECT COUNT(*) AS n FROM clients WHERE date_creation >= ? AND date_creation < ?',
      debutPeriode,
      finPeriode,
    );
    final nombreFournisseurs = await _compterSimple(
        'SELECT COUNT(*) AS n FROM suppliers', null, null);

    // ── Produits en rupture / alerte (liste détaillée) ──────────────────────
    //
    // Filtré en Dart plutôt qu'en SQL pour ne pas toucher
    // `ArticlesDao.getLowStockArticles`, partagé avec l'écran Alertes
    // (qui, lui, doit continuer à alerter sur TOUS les articles, dépôt
    // inclus — un stock de livres en dépôt qui s'épuise reste utile à
    // savoir pour recontacter l'auteur/l'éditeur).

    final depotSupplierIdsRows = await db
        .customSelect('SELECT id FROM suppliers WHERE est_depot = 1')
        .get();
    final depotSupplierIds = depotSupplierIdsRows
        .map((r) => r.data['id'] as int)
        .toSet();

    final articlesAlerteRaw = (await db.articlesDao.getLowStockArticles())
        .where((a) =>
            a.supplierId == null || !depotSupplierIds.contains(a.supplierId))
        .toList();
    final produitsEnRupture = articlesAlerteRaw
        .map((a) => ArticleEntity(
              id: a.id,
              code: a.code,
              nom: a.nom,
              categorieId: a.categorieId,
              prixAchat: a.prixAchat,
              prixVente: a.prixVente,
              stockMinimum: a.stockMinimum,
              stockTotal: a.stockTotal,
              dateCreation: a.dateCreation,
              actif: a.actif,
            ))
        .toList();

    // ── Top articles vendus (période sélectionnée) ──────────────────────────

    final produitsLesPlusVendus = <ProduitVenduEntity>[];
    try {
      final rows = await db.customSelect(
        '''
        SELECT l.article_id, a.nom,
               SUM(l.quantite) AS qte, SUM(l.total_ht) AS total
        FROM ($_lignesVenteAvecDepot) l
        JOIN articles a ON a.id = l.article_id
        WHERE l.est_depot = 0
          AND l.date_vente >= ? AND l.date_vente < ?
        GROUP BY l.article_id
        ORDER BY qte DESC
        LIMIT 10
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debutPeriode)),
          Variable.withInt(_epochSecondes(finPeriode)),
        ],
      ).get();
      for (final r in rows) {
        produitsLesPlusVendus.add(ProduitVenduEntity(
          articleId: r.data['article_id'] as int,
          articleNom: r.data['nom'] as String,
          quantiteVendue: (r.data['qte'] as num).toDouble(),
          totalVentes: (r.data['total'] as num).toDouble(),
        ));
      }
    } catch (_) {}

    // ── Top clients (période sélectionnée) ──────────────────────────────────

    final topClients = <TopClientEntity>[];
    try {
      final rows = await db.customSelect(
        '''
        SELECT l.client_id, c.nom,
               SUM(l.total_ttc) AS total, COUNT(DISTINCT l.doc_key) AS nb,
               COALESCE(c.dette_totale, 0.0) AS dette
        FROM ($_lignesVenteAvecDepot) l
        JOIN clients c ON c.id = l.client_id
        WHERE l.est_depot = 0 AND l.client_id IS NOT NULL
          AND l.date_vente >= ? AND l.date_vente < ?
        GROUP BY l.client_id
        ORDER BY total DESC
        LIMIT 10
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debutPeriode)),
          Variable.withInt(_epochSecondes(finPeriode)),
        ],
      ).get();
      for (final r in rows) {
        topClients.add(TopClientEntity(
          clientId: r.data['client_id'] as int,
          clientNom: r.data['nom'] as String,
          totalAchats: (r.data['total'] as num).toDouble(),
          nombreFactures: (r.data['nb'] as int),
          detteTotale: (r.data['dette'] as num).toDouble(),
        ));
      }
    } catch (_) {}

    // ── Articles dormants (sans vente depuis 30 jours, stock > 0) ───────────

    final debutDormance = debutJour.subtract(const Duration(days: 30));
    final articlesDormants = <ArticleEntity>[];
    try {
      final rows = await db.customSelect(
        '''
        SELECT a.id, a.code, a.nom, a.categorie_id, a.prix_achat, a.prix_vente,
               a.stock_minimum, a.actif, a.date_creation, a.stock_total
        FROM articles a
        WHERE a.actif = 1
          AND a.stock_total > 0
          AND $_excluDepotArticles
          AND a.id NOT IN (
            SELECT DISTINCT article_id FROM ($_lignesVenteAvecDepot)
            WHERE date_vente >= ?
          )
        ORDER BY a.nom
        LIMIT 10
        ''',
        variables: [Variable.withInt(_epochSecondes(debutDormance))],
      ).get();
      for (final r in rows) {
        articlesDormants.add(ArticleEntity(
          id: r.data['id'] as int,
          code: r.data['code'] as String? ?? '',
          nom: r.data['nom'] as String,
          categorieId: r.data['categorie_id'] as int?,
          prixAchat: (r.data['prix_achat'] as num).toDouble(),
          prixVente: (r.data['prix_vente'] as num).toDouble(),
          stockMinimum: (r.data['stock_minimum'] as num?)?.toDouble() ?? 0,
          stockTotal: (r.data['stock_total'] as num).toDouble(),
          dateCreation: DateTime.fromMillisecondsSinceEpoch(
              r.data['date_creation'] as int),
          actif: (r.data['actif'] as int) == 1,
        ));
      }
    } catch (_) {}

    // ── Graphiques ────────────────────────────────────────────────────────

    final ventesParJour = await _serieParJour(debutJour.subtract(const Duration(days: 6)), finJour, 7);
    final ventesParJour30 = await _serieParJour(debutJour.subtract(const Duration(days: 29)), finJour, 30);
    final ventesParMois12 = await _serieParMois(now, 12);

    // ── Pipeline documents V2 (alertes opérationnelles) ─────────────────────

    int proformasBrouillon = 0, bcEnAttente = 0;
    try {
      proformasBrouillon = (await db.commercialDocumentsDao
              .getParTypeEtStatut('proforma', 'brouillon'))
          .length;
      bcEnAttente = (await db.commercialDocumentsDao
              .getParTypeEtStatut('bon_commande', 'valide'))
          .length;
    } catch (_) {}

    // ── Conseils intelligents ─────────────────────────────────────────────

    final conseils = _genererConseils(
      ventesMois: ventesMois,
      ventesMoisPrecedent: ventesMoisPrecedent,
      topArticles: produitsLesPlusVendus,
      articlesEnRupture: produitsEnRupture,
      articlesDormants: articlesDormants,
      totalDettes: totalDettes,
      nombreClientsAvecDette: nbClientsAvecDette,
      proformasBrouillon: proformasBrouillon,
      achatsMois: achatsPeriode.$1,
    );

    return DashboardStatsEntity(
      ventesJour: ventesJour,
      ventesSemaine: ventesSemaine,
      ventesMois: ventesMois,
      ventesAnnee: ventesAnnee,
      caPeriodeSelectionnee: ventesPeriode.$1,
      beneficePeriodeSelectionnee: beneficePeriode,
      achatsPeriodeSelectionnee: achatsPeriode.$1,
      nombreVentesPeriode: ventesPeriode.$2,
      nombreFacturesPeriode: ventesPeriode.$2,
      nombreAchatsPeriode: achatsPeriode.$2,
      nombreDevisPeriode: nombreDevisPeriode,
      nombreProformasPeriode: nombreProformasPeriode,
      ventesMoisPrecedent: ventesMoisPrecedent,
      beneficeMoisPrecedent: beneficeMoisPrecedent,
      totalDettesClients: totalDettes,
      nombreClientsAvecDette: nbClientsAvecDette,
      nombreArticles: nombreArticles,
      valeurStock: valeurStock,
      nombreRuptures: nombreRuptures,
      nombreAlertes: nombreAlertes,
      nombreClients: nombreClients,
      nouveauxClientsPeriode: nouveauxClientsPeriode,
      nombreFournisseurs: nombreFournisseurs,
      produitsEnRupture: produitsEnRupture,
      produitsLesPlusVendus: produitsLesPlusVendus,
      topClients: topClients,
      articlesDormants: articlesDormants,
      ventesParJour: ventesParJour,
      ventesParJour30: ventesParJour30,
      ventesParMois12: ventesParMois12,
      nombreProformasBrouillon: proformasBrouillon,
      nombreBCEnAttente: bcEnAttente,
      conseils: conseils,
    );
  }

  // ── Bornes de dates ──────────────────────────────────────────────────────

  (DateTime, DateTime) _bornesPeriode(DashboardPeriode p, DateTime now) {
    final debutJour = DateTime(now.year, now.month, now.day);
    switch (p) {
      case DashboardPeriode.jour:
        return (debutJour, debutJour.add(const Duration(days: 1)));
      case DashboardPeriode.semaine:
        final debut = debutJour.subtract(Duration(days: debutJour.weekday - 1));
        return (debut, debut.add(const Duration(days: 7)));
      case DashboardPeriode.mois:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
      case DashboardPeriode.trimestre:
        final debutMoisTrimestre = ((now.month - 1) ~/ 3) * 3 + 1;
        return (
          DateTime(now.year, debutMoisTrimestre, 1),
          DateTime(now.year, debutMoisTrimestre + 3, 1),
        );
      case DashboardPeriode.semestre:
        final debutMoisSemestre = ((now.month - 1) ~/ 6) * 6 + 1;
        return (
          DateTime(now.year, debutMoisSemestre, 1),
          DateTime(now.year, debutMoisSemestre + 6, 1),
        );
      case DashboardPeriode.annee:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
    }
  }

  // ── Requêtes bornées ─────────────────────────────────────────────────────

  Future<double> _sommeVentes(DateTime debut, DateTime fin) async {
    final r = await _ventesEtCompte(debut, fin);
    return r.$1;
  }

  /// Retourne (montant total, nombre de ventes) pour l'intervalle donné,
  /// hors dépôt-vente.
  Future<(double, int)> _ventesEtCompte(DateTime debut, DateTime fin) async {
    try {
      final row = await db.customSelect(
        '''
        SELECT COALESCE(SUM(l.total_ttc), 0.0) AS t, COUNT(DISTINCT l.doc_key) AS n
        FROM ($_lignesVenteAvecDepot) l
        WHERE l.est_depot = 0 AND l.date_vente >= ? AND l.date_vente < ?
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debut)),
          Variable.withInt(_epochSecondes(fin)),
        ],
      ).getSingle();
      return (
        (row.data['t'] as num?)?.toDouble() ?? 0.0,
        (row.data['n'] as int?) ?? 0,
      );
    } catch (_) {
      return (0.0, 0);
    }
  }

  /// Retourne (montant total, nombre d'achats) pour l'intervalle donné.
  ///
  /// Ne compte que les achats réceptionnés (`statut = 'recu'`) : depuis
  /// l'ajout des bons de commande fournisseur (V3.0.0), un achat au
  /// statut 'commande' n'a pas encore impacté le stock ni été livré,
  /// et ne doit donc pas gonfler le CA achats / le nombre d'achats du
  /// tableau de bord tant qu'il n'est pas reçu.
  Future<(double, int)> _achatsEtCompte(DateTime debut, DateTime fin) async {
    try {
      final row = await db.customSelect(
        '''
        SELECT COALESCE(SUM(total_final), 0.0) AS t, COUNT(*) AS n
        FROM purchases
        WHERE date_creation >= ? AND date_creation < ? AND statut = 'recu'
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debut)),
          Variable.withInt(_epochSecondes(fin)),
        ],
      ).getSingle();
      return (
        (row.data['t'] as num?)?.toDouble() ?? 0.0,
        (row.data['n'] as int?) ?? 0,
      );
    } catch (_) {
      return (0.0, 0);
    }
  }

  /// Marge brute (prix de vente ligne − coût d'achat actuel de
  /// l'article) sur l'intervalle donné, calculée en une seule requête
  /// SQL (remplace l'ancienne boucle N+1 qui rechargeait chaque
  /// facture puis chaque article individuellement).
  Future<double> _beneficeSurPeriode(DateTime debut, DateTime fin) async {
    try {
      final row = await db.customSelect(
        '''
        SELECT COALESCE(SUM(l.total_ht - (l.prix_achat * l.quantite)), 0.0) AS marge
        FROM ($_lignesVenteAvecDepot) l
        WHERE l.est_depot = 0 AND l.date_vente >= ? AND l.date_vente < ?
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debut)),
          Variable.withInt(_epochSecondes(fin)),
        ],
      ).getSingle();
      return (row.data['marge'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<int> _compterSimple(String sql, DateTime? debut, DateTime? fin) async {
    try {
      final row = await db.customSelect(
        sql,
        variables: [
          if (debut != null) Variable.withInt(_epochSecondes(debut)),
          if (fin != null) Variable.withInt(_epochSecondes(fin)),
        ],
      ).getSingle();
      return (row.data['n'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Récupère (date_vente en secondes UTC, montant) sur l'intervalle
  /// donné. Le regroupement par jour/mois se fait ensuite côté Dart
  /// (voir [_serieParJour]/[_serieParMois]) plutôt qu'avec le
  /// modificateur SQLite `'localtime'`, dont la disponibilité dépend
  /// des données de fuseau horaire du système et qui peut renvoyer
  /// NULL silencieusement selon l'environnement — `DateTime.
  /// fromMillisecondsSinceEpoch` gère cette conversion de façon fiable.
  Future<List<(int, double)>> _venteBrutes(DateTime debut, DateTime fin) async {
    try {
      final rows = await db.customSelect(
        '''
        SELECT l.date_vente AS date_vente, l.total_ttc AS montant
        FROM ($_lignesVenteAvecDepot) l
        WHERE l.est_depot = 0 AND l.date_vente >= ? AND l.date_vente < ?
        ''',
        variables: [
          Variable.withInt(_epochSecondes(debut)),
          Variable.withInt(_epochSecondes(fin)),
        ],
      ).get();
      return [
        for (final r in rows)
          (
            r.data['date_vente'] as int,
            (r.data['montant'] as num).toDouble(),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<PointVenteEntity>> _serieParJour(
      DateTime debut, DateTime fin, int nbJours) async {
    final ventes = await _venteBrutes(debut, fin);
    final map = <String, double>{};
    for (final (dateVenteSecondes, montant) in ventes) {
      final d = DateTime.fromMillisecondsSinceEpoch(dateVenteSecondes * 1000);
      final cle = _cleJour(d);
      map[cle] = (map[cle] ?? 0) + montant;
    }

    final debutJourLocal = DateTime(debut.year, debut.month, debut.day);
    return [
      for (int i = 0; i < nbJours; i++)
        () {
          final jour = debutJourLocal.add(Duration(days: i));
          return PointVenteEntity(
            date: jour,
            total: map[_cleJour(jour)] ?? 0,
          );
        }(),
    ];
  }

  Future<List<PointVenteEntity>> _serieParMois(DateTime now, int nbMois) async {
    final debut = _decalerMois(DateTime(now.year, now.month, 1), -(nbMois - 1));
    final fin = DateTime(now.year, now.month + 1, 1);
    final ventes = await _venteBrutes(debut, fin);
    final map = <String, double>{};
    for (final (dateVenteSecondes, montant) in ventes) {
      final d = DateTime.fromMillisecondsSinceEpoch(dateVenteSecondes * 1000);
      final cle = _cleMois(d);
      map[cle] = (map[cle] ?? 0) + montant;
    }

    return [
      for (int i = nbMois - 1; i >= 0; i--)
        () {
          final m = _decalerMois(now, -i);
          return PointVenteEntity(date: m, total: map[_cleMois(m)] ?? 0);
        }(),
    ];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Drift stocke les colonnes `DateTime` en secondes unix (INTEGER),
  /// pas en millisecondes. Toute comparaison SQL brute doit donc
  /// convertir les bornes Dart via cette fonction — une comparaison
  /// directe avec `.millisecondsSinceEpoch` ne matche jamais aucune
  /// ligne (le nombre de millisecondes est ~1000× plus grand que la
  /// valeur réellement stockée), ce qui était la cause du bug où les
  /// statistiques du tableau de bord restaient bloquées à 0.
  int _epochSecondes(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  String _cleJour(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _cleMois(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  DateTime _decalerMois(DateTime d, int delta) {
    int m = d.month + delta;
    int y = d.year;
    while (m < 1) {
      m += 12;
      y--;
    }
    while (m > 12) {
      m -= 12;
      y++;
    }
    return DateTime(y, m, 1);
  }

  List<ConseilDashboard> _genererConseils({
    required double ventesMois,
    required double ventesMoisPrecedent,
    required List<ProduitVenduEntity> topArticles,
    required List<ArticleEntity> articlesEnRupture,
    required List<ArticleEntity> articlesDormants,
    required double totalDettes,
    required int nombreClientsAvecDette,
    required int proformasBrouillon,
    required double achatsMois,
  }) {
    final conseils = <ConseilDashboard>[];

    if (ventesMoisPrecedent > 0) {
      final delta =
          ((ventesMois - ventesMoisPrecedent) / ventesMoisPrecedent * 100)
              .round();
      if (delta >= 5) {
        conseils.add(ConseilDashboard(
          message:
              'CA en hausse de $delta% par rapport au mois dernier. Continuez sur cette lancée !',
          type: ConseilType.success,
        ));
      } else if (delta <= -10) {
        conseils.add(ConseilDashboard(
          message:
              'CA en baisse de ${-delta}% par rapport au mois dernier. Pensez à relancer vos clients.',
          type: ConseilType.warning,
        ));
      }
    }

    if (topArticles.isNotEmpty) {
      final top = topArticles.first;
      conseils.add(ConseilDashboard(
        message:
            '${top.articleNom} est votre meilleur article sur la période avec '
            '${top.quantiteVendue.toStringAsFixed(0)} unité(s) vendue(s).',
        type: ConseilType.info,
      ));
    }

    final ruptures = articlesEnRupture.where((a) => a.estEnRuptureTotale).length;
    if (ruptures > 0) {
      conseils.add(ConseilDashboard(
        message:
            '$ruptures article(s) en rupture totale de stock. Réapprovisionner rapidement.',
        type: ConseilType.danger,
      ));
    }

    if (articlesDormants.isNotEmpty) {
      conseils.add(ConseilDashboard(
        message:
            '${articlesDormants.length} article(s) n\'ont pas été vendus depuis '
            '30 jours malgré un stock disponible.',
        type: ConseilType.warning,
      ));
    }

    if (totalDettes > 0) {
      conseils.add(ConseilDashboard(
        message:
            '$nombreClientsAvecDette client(s) ont des dettes en cours. '
            'Pensez à effectuer les relances.',
        type: ConseilType.warning,
      ));
    }

    if (proformasBrouillon > 0) {
      conseils.add(ConseilDashboard(
        message:
            '$proformasBrouillon proforma(s) en attente de conversion. '
            'Relancez vos prospects.',
        type: ConseilType.info,
      ));
    }

    if (achatsMois == 0) {
      conseils.add(ConseilDashboard(
        message:
            'Aucun achat fournisseur enregistré sur la période. '
            'Pensez à renouveler vos stocks.',
        type: ConseilType.info,
      ));
    }

    return conseils;
  }
}
