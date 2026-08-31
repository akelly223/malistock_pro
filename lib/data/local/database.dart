import 'dart:io';
import 'dart:developer' as dev;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/users_table.dart';
import 'tables/stores_table.dart';
import 'tables/categories_table.dart';
import 'tables/articles_table.dart';
import 'tables/clients_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/quotes_table.dart';
import 'tables/invoices_table.dart';
import 'tables/purchases_table.dart';
import 'tables/payments_table.dart';
import 'tables/client_debts_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/stock_transfers_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/document_counters_table.dart';
import 'tables/tva_rates_table.dart';
import 'tables/commercial_documents_table.dart';
import 'tables/document_lines_table.dart';
import 'tables/document_payments_table.dart';
import 'tables/document_history_table.dart';
import 'tables/drafts_table.dart';
import 'tables/inventories_table.dart';
import 'tables/depot_vente_reglements_table.dart';
import 'tables/depot_vente_reglement_lignes_table.dart';

import 'daos/users_dao.dart';
import 'daos/stores_dao.dart';
import 'daos/articles_dao.dart';
import 'daos/clients_dao.dart';
import 'daos/suppliers_dao.dart';
import 'daos/quotes_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/purchases_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/stock_dao.dart';
import 'daos/app_settings_dao.dart';
import 'daos/document_counters_dao.dart';
import 'daos/tva_rates_dao.dart';
import 'daos/commercial_documents_dao.dart';
import 'daos/draft_dao.dart';
import 'daos/inventories_dao.dart';

import '../../core/constants/app_identity.dart';
import '../../core/constants/db_constants.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Stores,
    Categories,
    Articles,
    ArticleStocks,
    Clients,
    Suppliers,
    Quotes,
    QuoteItems,
    Invoices,
    InvoiceItems,
    Purchases,
    PurchaseItems,
    Payments,
    ClientDebts,
    StockMovements,
    StockTransfers,
    AppSettings,
    DocumentCounters,
    TvaRates,
    CommercialDocuments,
    DocumentLines,
    DocumentPayments,
    DocumentHistories,
    Drafts,
    Inventories,
    InventoryLines,
    DepotVenteReglements,
    DepotVenteReglementLignes,
  ],
  daos: [
    UsersDao,
    StoresDao,
    ArticlesDao,
    ClientsDao,
    SuppliersDao,
    QuotesDao,
    InvoicesDao,
    PurchasesDao,
    PaymentsDao,
    StockDao,
    AppSettingsDao,
    DocumentCountersDao,
    TvaRatesDao,
    CommercialDocumentsDao,
    DraftDao,
    InventoriesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.withExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          _log('onCreate → schemaVersion $schemaVersion : création de toutes les tables');
          await m.createAll();
          _log('onCreate terminé avec succès');
        },

        onUpgrade: (Migrator m, int from, int to) async {
          _log('onUpgrade : migration de v$from vers v$to');

          // Chaque bloc est ENTIÈREMENT IDEMPOTENT :
          // on vérifie l'existence de chaque table/colonne avant
          // d'agir, pour survivre à une base dont le user_version
          // aurait été mal enregistré (crash pendant une migration,
          // remplacement de fichier sqlite, etc.).

          if (from < 2) {
            _log('Migration v2 : achats fournisseurs');
            await _creerTableSiAbsente('purchases', () => m.createTable(purchases));
            await _creerTableSiAbsente('purchase_items', () => m.createTable(purchaseItems));
            await _ajouterColonneSiAbsente('payments', 'purchase_id',
                'ALTER TABLE payments ADD COLUMN purchase_id INTEGER NULL REFERENCES purchases(id)');
          }

          if (from < 3) {
            _log('Migration v3 : paramètres entreprise');
            await _creerTableSiAbsente('app_settings', () => m.createTable(appSettings));
          }

          if (from < 4) {
            _log('Migration v4 : email/slogan/commentaire entreprise');
            await _ajouterColonneSiAbsente('app_settings', 'email',
                "ALTER TABLE app_settings ADD COLUMN email TEXT NULL");
            await _ajouterColonneSiAbsente('app_settings', 'slogan',
                "ALTER TABLE app_settings ADD COLUMN slogan TEXT NULL");
            await _ajouterColonneSiAbsente('app_settings', 'commentaire_pied_de_page',
                "ALTER TABLE app_settings ADD COLUMN commentaire_pied_de_page TEXT NOT NULL DEFAULT 'Merci pour votre confiance. Revenez bientot.'");
          }

          if (from < 5) {
            _log('Migration v5 : compteurs de numérotation robuste');
            await _creerTableSiAbsente('document_counters', () => m.createTable(documentCounters));
            await _initialiserCompteursDepuisExistant();
          }

          if (from < 6) {
            _log('Migration v6 : traçabilité modifications achats');
            await _ajouterColonneSiAbsente('purchases', 'date_modification',
                'ALTER TABLE purchases ADD COLUMN date_modification INTEGER NULL');
            await _ajouterColonneSiAbsente('purchases', 'modifie_par_user_id',
                'ALTER TABLE purchases ADD COLUMN modifie_par_user_id INTEGER NULL REFERENCES users(id)');
          }

          if (from < 7) {
            _log('Migration v7 : tables V2 + migration données V1→V2');

            // ── Nouvelles tables ─────────────────────────────────────────────
            await _creerTableSiAbsente(
                'tva_rates', () => m.createTable(tvaRates));
            await _creerTableSiAbsente(
                'commercial_documents', () => m.createTable(commercialDocuments));
            await _creerTableSiAbsente(
                'document_lines', () => m.createTable(documentLines));
            await _creerTableSiAbsente(
                'document_payments', () => m.createTable(documentPayments));
            await _creerTableSiAbsente(
                'document_histories', () => m.createTable(documentHistories));

            // ── Taux TVA initiaux ────────────────────────────────────────────
            await customStatement('''
              INSERT OR IGNORE INTO tva_rates(taux, libelle, actif) VALUES
              (0.0,  'Exonéré (0%)',       1),
              (18.0, 'TVA normale (18%)',  1)
            ''');

            // ── Colonnes supplémentaires sur tables existantes ───────────────
            await _ajouterColonneSiAbsente('articles', 'taux_tva_defaut',
                'ALTER TABLE articles ADD COLUMN taux_tva_defaut REAL NOT NULL DEFAULT 18');
            await _ajouterColonneSiAbsente('clients', 'tva_applicable',
                'ALTER TABLE clients ADD COLUMN tva_applicable INTEGER NOT NULL DEFAULT 1');
            await _ajouterColonneSiAbsente('clients', 'delai_paiement_jours',
                'ALTER TABLE clients ADD COLUMN delai_paiement_jours INTEGER NULL');
            await _ajouterColonneSiAbsente('clients', 'conditions_reglement',
                'ALTER TABLE clients ADD COLUMN conditions_reglement TEXT NULL');

            // ── Migration factures V1 → commercial_documents ─────────────────
            // Les factures V1 sont conservées intactes ; on en crée une copie
            // dans le modèle V2.  INSERT OR IGNORE évite les doublons si la
            // migration est relancée (numero est UNIQUE).
            await customStatement('''
              INSERT OR IGNORE INTO commercial_documents (
                numero, type, statut,
                client_id, store_id,
                date_document, date_creation,
                created_by_id,
                total_ht, total_tva, total_ttc,
                remise_globale_pct, montant_paye, statut_paiement
              )
              SELECT
                i.numero, 'facture', 'valide',
                i.client_id, i.store_id,
                i.date_creation, i.date_creation,
                i.user_id,
                i.total_ht, 0.0, i.total_final,
                i.remise_globale, i.montant_paye, i.statut_paiement
              FROM invoices i
            ''');

            // ── Migration lignes factures V1 → document_lines ────────────────
            // Idempotent : ne s'exécute que si document_lines est encore vide.
            await customStatement('''
              INSERT INTO document_lines (
                document_id, article_id, article_code, article_nom,
                quantite, prix_unitaire_ht, taux_tva,
                remise_ligne_pct, total_ht, montant_tva, total_ttc, position
              )
              SELECT
                cd.id, ii.article_id, a.code, a.nom,
                ii.quantite, ii.prix_unitaire, 0.0,
                ii.remise_pourcentage, ii.total_ligne, 0.0, ii.total_ligne,
                ii.id
              FROM invoice_items ii
              JOIN invoices i     ON ii.invoice_id = i.id
              JOIN commercial_documents cd ON cd.numero = i.numero
              JOIN articles a     ON ii.article_id = a.id
              WHERE NOT EXISTS (SELECT 1 FROM document_lines LIMIT 1)
            ''');

            // ── Migration devis V1 → commercial_documents (type proforma) ────
            await customStatement('''
              INSERT OR IGNORE INTO commercial_documents (
                numero, type, statut,
                client_id, store_id,
                date_document, date_creation,
                total_ht, total_tva, total_ttc, remise_globale_pct
              )
              SELECT
                q.numero, 'proforma',
                CASE q.statut
                  WHEN 'converti' THEN 'transforme'
                  WHEN 'expire'   THEN 'annule'
                  ELSE 'valide'
                END,
                q.client_id, q.store_id,
                q.date_creation, q.date_creation,
                q.total_ht, 0.0, q.total_final, q.remise_globale
              FROM quotes q
            ''');

            // ── Migration lignes devis V1 → document_lines ───────────────────
            await customStatement('''
              INSERT INTO document_lines (
                document_id, article_id, article_code, article_nom,
                quantite, prix_unitaire_ht, taux_tva,
                remise_ligne_pct, total_ht, montant_tva, total_ttc, position
              )
              SELECT
                cd.id, qi.article_id, a.code, a.nom,
                qi.quantite, qi.prix_unitaire, 0.0,
                qi.remise_pourcentage, qi.total_ligne, 0.0, qi.total_ligne,
                qi.id
              FROM quote_items qi
              JOIN quotes q ON qi.quote_id = q.id
              JOIN commercial_documents cd ON cd.numero = q.numero
              JOIN articles a ON qi.article_id = a.id
              WHERE NOT EXISTS (
                SELECT 1 FROM document_lines dl
                JOIN commercial_documents cd2 ON dl.document_id = cd2.id
                WHERE cd2.type = 'proforma'
                LIMIT 1
              )
            ''');

            // ── Migration paiements V1 → document_payments ───────────────────
            await customStatement('''
              INSERT INTO document_payments (
                document_id, montant, date_paiement, mode_paiement, date_creation
              )
              SELECT
                cd.id,
                p.montant,
                p.date_paiement,
                CASE p.mode_paiement
                  WHEN 'orange_money' THEN 'mobile_money'
                  WHEN 'moov_money'   THEN 'mobile_money'
                  ELSE p.mode_paiement
                END,
                p.date_paiement
              FROM payments p
              JOIN invoices i ON p.invoice_id = i.id
              JOIN commercial_documents cd ON cd.numero = i.numero
              WHERE p.invoice_id IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM document_payments LIMIT 1)
            ''');
          }

          if (from < 9) {
            _log('Migration v9 : traçabilité modifications factures V1');
            await _ajouterColonneSiAbsente('invoices', 'date_modification',
                'ALTER TABLE invoices ADD COLUMN date_modification INTEGER NULL');
            await _ajouterColonneSiAbsente('invoices', 'modifie_par_user_id',
                'ALTER TABLE invoices ADD COLUMN modifie_par_user_id INTEGER NULL REFERENCES users(id)');
          }

          if (from < 10) {
            _log('Migration v10 : table brouillons automatiques');
            await _creerTableSiAbsente('drafts', () => m.createTable(drafts));
          }

          if (from < 11) {
            _log('Migration v11 : NIF client');
            await _ajouterColonneSiAbsente('clients', 'nif',
                'ALTER TABLE clients ADD COLUMN nif TEXT NULL');
          }

          if (from < 12) {
            _log('Migration v12 : numéro de reçu sur les paiements');
            await _ajouterColonneSiAbsente('payments', 'numero_recu',
                'ALTER TABLE payments ADD COLUMN numero_recu TEXT NULL');
            await _ajouterColonneSiAbsente('document_payments', 'numero_recu',
                'ALTER TABLE document_payments ADD COLUMN numero_recu TEXT NULL');
          }

          if (from < 8) {
            _log('Migration v8 : NIF, RCCM, IFU, TVA, devise, signature, cachet');
            await _ajouterColonneSiAbsente('app_settings', 'nif',
                'ALTER TABLE app_settings ADD COLUMN nif TEXT NULL');
            await _ajouterColonneSiAbsente('app_settings', 'rccm',
                'ALTER TABLE app_settings ADD COLUMN rccm TEXT NULL');
            await _ajouterColonneSiAbsente('app_settings', 'ifu',
                'ALTER TABLE app_settings ADD COLUMN ifu TEXT NULL');
            await _ajouterColonneSiAbsente('app_settings', 'tva_active',
                'ALTER TABLE app_settings ADD COLUMN tva_active INTEGER NOT NULL DEFAULT 0');
            await _ajouterColonneSiAbsente('app_settings', 'taux_tva',
                'ALTER TABLE app_settings ADD COLUMN taux_tva REAL NOT NULL DEFAULT 18.0');
            await _ajouterColonneSiAbsente('app_settings', 'devise',
                "ALTER TABLE app_settings ADD COLUMN devise TEXT NOT NULL DEFAULT 'FCFA'");
            await _ajouterColonneSiAbsente('app_settings', 'signature_path',
                'ALTER TABLE app_settings ADD COLUMN signature_path TEXT NULL');
            await _ajouterColonneSiAbsente('app_settings', 'cachet_path',
                'ALTER TABLE app_settings ADD COLUMN cachet_path TEXT NULL');
          }

          if (from < 13) {
            _log('Migration v13 : module Inventaire');
            await _creerTableSiAbsente(
                'inventories', () => m.createTable(inventories));
            await _creerTableSiAbsente(
                'inventory_lines', () => m.createTable(inventoryLines));
          }

          if (from < 14) {
            _log('Migration v14 : dépôt-vente auteurs');
            await _ajouterColonneSiAbsente('suppliers', 'est_depot',
                'ALTER TABLE suppliers ADD COLUMN est_depot INTEGER NOT NULL DEFAULT 0');
            await _ajouterColonneSiAbsente('suppliers', 'part_auteur_pct',
                'ALTER TABLE suppliers ADD COLUMN part_auteur_pct REAL NOT NULL DEFAULT 0');
            await _ajouterColonneSiAbsente('articles', 'supplier_id',
                'ALTER TABLE articles ADD COLUMN supplier_id INTEGER NULL REFERENCES suppliers(id)');
          }

          if (from < 15) {
            _log('Migration v15 : regroupement des mouvements de stock manuels');
            await _ajouterColonneSiAbsente('stock_movements', 'groupe_id',
                'ALTER TABLE stock_movements ADD COLUMN groupe_id TEXT NULL');
          }

          if (from < 16) {
            _log('Migration v16 : bon de commande fournisseur');
            await _ajouterColonneSiAbsente('purchases', 'statut',
                "ALTER TABLE purchases ADD COLUMN statut TEXT NOT NULL DEFAULT 'recu'");
          }

          if (from < 17) {
            _log('Migration v17 : description article');
            await _ajouterColonneSiAbsente('articles', 'description',
                'ALTER TABLE articles ADD COLUMN description TEXT NULL');
          }

          if (from < 18) {
            _log('Migration v18 : historique règlements dépôt-vente + prix euro article');
            await _creerTableSiAbsente('depot_vente_reglements',
                () => m.createTable(depotVenteReglements));
            await _creerTableSiAbsente('depot_vente_reglement_lignes',
                () => m.createTable(depotVenteReglementLignes));

            // Défensif : si une build de test antérieure a déjà créé
            // depot_vente_reglements avec l'ancien schéma (montant_total,
            // sans détail par livre), on complète sans perte de données au
            // lieu de dupliquer la table.
            if (await _colonneExiste('depot_vente_reglements', 'montant_total') &&
                !await _colonneExiste('depot_vente_reglements', 'montant_paye')) {
              await customStatement(
                  'ALTER TABLE depot_vente_reglements RENAME COLUMN montant_total TO montant_paye');
            }
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'montant_du',
                'ALTER TABLE depot_vente_reglements ADD COLUMN montant_du REAL NOT NULL DEFAULT 0');
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'statut',
                "ALTER TABLE depot_vente_reglements ADD COLUMN statut TEXT NOT NULL DEFAULT 'regle'");
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'note',
                'ALTER TABLE depot_vente_reglements ADD COLUMN note TEXT NULL');
            // Anciens règlements (tout-ou-rien) : montant dû = montant payé.
            await customStatement(
                'UPDATE depot_vente_reglements SET montant_du = montant_paye WHERE montant_du = 0');

            await _ajouterColonneSiAbsente('articles', 'prix_euro',
                'ALTER TABLE articles ADD COLUMN prix_euro REAL NULL');
            await _ajouterColonneSiAbsente('articles', 'taux_conversion_euro',
                'ALTER TABLE articles ADD COLUMN taux_conversion_euro REAL NULL');
          }

          if (from < 19) {
            // Répare les bases dont le user_version est déjà à 18 alors que
            // le bloc précédent (montant_du/statut/note) n'a jamais tourné :
            // arrivé pendant le développement de cette fonctionnalité, ce
            // schemaVersion a pu être enregistré par une build antérieure
            // qui créait déjà `depot_vente_reglements` (via createTable, à
            // partir d'une définition de table plus ancienne) sans que le
            // correctif idempotent ci-dessus ne soit encore rejoué — d'où
            // "no such column: montant_du" malgré la présence de ce bloc.
            _log('Migration v19 : réparation colonnes historique règlements dépôt-vente');
            await _creerTableSiAbsente('depot_vente_reglements',
                () => m.createTable(depotVenteReglements));
            await _creerTableSiAbsente('depot_vente_reglement_lignes',
                () => m.createTable(depotVenteReglementLignes));

            if (await _colonneExiste('depot_vente_reglements', 'montant_total') &&
                !await _colonneExiste('depot_vente_reglements', 'montant_paye')) {
              await customStatement(
                  'ALTER TABLE depot_vente_reglements RENAME COLUMN montant_total TO montant_paye');
            }
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'montant_du',
                'ALTER TABLE depot_vente_reglements ADD COLUMN montant_du REAL NOT NULL DEFAULT 0');
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'statut',
                "ALTER TABLE depot_vente_reglements ADD COLUMN statut TEXT NOT NULL DEFAULT 'regle'");
            await _ajouterColonneSiAbsente('depot_vente_reglements', 'note',
                'ALTER TABLE depot_vente_reglements ADD COLUMN note TEXT NULL');
            await customStatement(
                'UPDATE depot_vente_reglements SET montant_du = montant_paye WHERE montant_du = 0');
          }

          _log('Migration v$from → v$to terminée avec succès');
        },

        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          _log(
            'beforeOpen : '
            'base=${details.hadUpgrade ? "mise à jour" : details.wasCreated ? "créée" : "existante"}, '
            'schemaVersion=${details.versionNow}, '
            'versionPrécédente=${details.versionBefore}',
          );
        },
      );

  // ─── Helpers de migration idempotents ───────────────────────────

  /// Crée une table SQLite seulement si elle n'existe pas encore.
  Future<void> _creerTableSiAbsente(
      String nomTable, Future<void> Function() creer) async {
    final existe = await _tableExiste(nomTable);
    if (existe) {
      _log('  table "$nomTable" déjà présente — sautée');
    } else {
      await creer();
      _log('  table "$nomTable" créée');
    }
  }

  /// Ajoute une colonne seulement si elle est absente (PRAGMA table_info).
  Future<void> _ajouterColonneSiAbsente(
      String table, String colonne, String sql) async {
    if (await _colonneExiste(table, colonne)) {
      _log('  colonne "$table.$colonne" déjà présente — sautée');
    } else {
      await customStatement(sql);
      _log('  colonne "$table.$colonne" ajoutée');
    }
  }

  Future<bool> _tableExiste(String nomTable) async {
    final result = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(nomTable)],
    ).get();
    return result.isNotEmpty;
  }

  Future<bool> _colonneExiste(String table, String colonne) async {
    final result = await customSelect(
      'PRAGMA table_info($table)',
    ).get();
    return result.any((row) => row.data['name'] == colonne);
  }

  static void _log(String message) {
    dev.log('[Migration] $message', name: 'AppDatabase');
    // ignore: avoid_print
    print('[AppDatabase] $message');
  }

  // ─── Données de diagnostic exposées à l'UI ──────────────────────

  /// Retourne toutes les informations utiles au diagnostic technique :
  /// versions, chemin de la base, compteurs, intégrité, sauvegardes, etc.
  ///
  /// Chaque accès est protégé par try/catch pour ne jamais lever d'exception :
  /// une information indisponible est retournée null ou avec une valeur par défaut.
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    // ── Fichier de base de données ────────────────────────────────────
    final cheminDossier = await getDatabaseDirectory();
    final cheminFichier = p.join(cheminDossier, DbConstants.dbFileName);
    final fichier = File(cheminFichier);

    DateTime? dateModification;
    int? tailleFichier;
    try {
      if (await fichier.exists()) {
        final stat = await fichier.stat();
        dateModification = stat.modified;
        tailleFichier = stat.size;
      }
    } catch (_) {}

    // ── Versions SQLite ───────────────────────────────────────────────
    String? sqliteVersion;
    try {
      final r = await customSelect('SELECT sqlite_version() AS v').getSingle();
      sqliteVersion = r.data['v'] as String?;
    } catch (_) {}

    int? userVersion;
    try {
      final r = await customSelect('PRAGMA user_version').getSingle();
      userVersion = r.data['user_version'] as int?;
    } catch (_) {}

    // ── Tables présentes ──────────────────────────────────────────────
    List<String> tablesPresentes = [];
    try {
      final rows = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
          .get();
      tablesPresentes = rows.map((r) => r.data['name'] as String).toList();
    } catch (_) {}

    // ── Compteurs d'enregistrements ───────────────────────────────────
    Future<int> compter(String table) async {
      try {
        final r = await customSelect(
                'SELECT COUNT(*) AS n FROM "$table"')
            .getSingle();
        return (r.data['n'] as int?) ?? 0;
      } catch (_) {
        return 0;
      }
    }

    final nbArticles         = await compter('articles');
    final nbClients          = await compter('clients');
    final nbFournisseurs     = await compter('suppliers');
    final nbFacturesV1       = await compter('invoices');
    final nbDocumentsV2      = await compter('commercial_documents');
    final nbAchats           = await compter('purchases');
    final nbMouvementsStock  = await compter('stock_movements');

    // ── Vérification d'intégrité SQLite ──────────────────────────────
    String integrite = 'Non disponible';
    try {
      final rows = await customSelect('PRAGMA integrity_check').get();
      final resultats =
          rows.map((r) => r.data.values.first?.toString() ?? '').toList();
      integrite = (resultats.length == 1 && resultats.first == 'ok')
          ? 'ok'
          : resultats.join(' | ');
    } catch (_) {}

    // ── Dernière sauvegarde ───────────────────────────────────────────
    DateTime? derniereSauvegarde;
    int nombreSauvegardes = 0;
    try {
      final backupDir = Directory(p.join(cheminDossier, 'sauvegardes'));
      if (await backupDir.exists()) {
        final fichiers = backupDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.zip'))
            .toList();
        fichiers.sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
        nombreSauvegardes = fichiers.length;
        if (fichiers.isNotEmpty) {
          derniereSauvegarde = fichiers.first.statSync().modified;
        }
      }
    } catch (_) {}

    // ── Colonnes importantes (vérification des migrations) ────────────
    final colonnesImportantes = <String, bool>{
      'purchases.date_modification':
          await _colonneExiste('purchases', 'date_modification'),
      'purchases.modifie_par_user_id':
          await _colonneExiste('purchases', 'modifie_par_user_id'),
      'app_settings.email':
          await _colonneExiste('app_settings', 'email'),
      'app_settings.slogan':
          await _colonneExiste('app_settings', 'slogan'),
      'app_settings.nif':
          await _colonneExiste('app_settings', 'nif'),
      'app_settings.tva_active':
          await _colonneExiste('app_settings', 'tva_active'),
      'payments.purchase_id':
          await _colonneExiste('payments', 'purchase_id'),
      'articles.taux_tva_defaut':
          await _colonneExiste('articles', 'taux_tva_defaut'),
      'clients.tva_applicable':
          await _colonneExiste('clients', 'tva_applicable'),
    };

    return {
      // Application
      'versionApp'         : AppIdentity.version,
      // SQLite
      'sqliteVersion'      : sqliteVersion,
      'schemaVersionCode'  : schemaVersion,
      'userVersionBase'    : userVersion,
      'migrationNecessaire': userVersion != null && userVersion != schemaVersion,
      // Fichier
      'cheminFichier'      : cheminFichier,
      'cheminDossier'      : cheminDossier,
      'fichierExiste'      : await fichier.exists(),
      'tailleFichier'      : tailleFichier,
      'dateModification'   : dateModification,
      // Compteurs
      'nbArticles'         : nbArticles,
      'nbClients'          : nbClients,
      'nbFournisseurs'     : nbFournisseurs,
      'nbFacturesV1'       : nbFacturesV1,
      'nbDocumentsV2'      : nbDocumentsV2,
      'nbAchats'           : nbAchats,
      'nbMouvementsStock'  : nbMouvementsStock,
      // Intégrité
      'integrite'          : integrite,
      // Sauvegardes
      'derniereSauvegarde' : derniereSauvegarde,
      'nombreSauvegardes'  : nombreSauvegardes,
      // Migrations
      'tablesPresentes'    : tablesPresentes,
      'colonnesImportantes': colonnesImportantes,
    };
  }

  // ─── Initialisation des compteurs depuis l'existant ─────────────

  Future<void> _initialiserCompteursDepuisExistant() async {
    final annee = DateTime.now().year;

    Future<void> initialiserPour(
      String prefixeDocument,
      Future<List<String>> Function() lireTousLesNumeros,
    ) async {
      final tousLesNumeros = await lireTousLesNumeros();
      int maxNumero = 0;
      final prefixAnnee = '$prefixeDocument-$annee-';
      for (final numero in tousLesNumeros) {
        if (!numero.startsWith(prefixAnnee)) continue;
        final suffixe = numero.substring(prefixAnnee.length);
        final valeur = int.tryParse(suffixe);
        if (valeur != null && valeur > maxNumero) {
          maxNumero = valeur;
        }
      }
      if (maxNumero > 0) {
        await into(documentCounters).insertOnConflictUpdate(
          DocumentCountersCompanion.insert(
            cle: '$prefixeDocument-$annee',
            dernierNumero: Value(maxNumero),
          ),
        );
      }
    }

    await initialiserPour('FAC', () async {
      final rows = await select(invoices).get();
      return rows.map((r) => r.numero).toList();
    });
    await initialiserPour('ACH', () async {
      final rows = await select(purchases).get();
      return rows.map((r) => r.numero).toList();
    });
    await initialiserPour('DEV', () async {
      final rows = await select(quotes).get();
      return rows.map((r) => r.numero).toList();
    });
  }

  // ─── Chemin de la base ──────────────────────────────────────────

  static Future<String> getDatabaseDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'MaliStockPro');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final folderPath = await AppDatabase.getDatabaseDirectory();
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File(p.join(folderPath, DbConstants.dbFileName));
    AppDatabase._log('Ouverture de la base : ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
