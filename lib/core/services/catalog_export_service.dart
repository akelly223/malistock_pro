import 'package:flutter/foundation.dart' show compute;

import '../../domain/entities/article.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/supplier.dart';
import '../utils/csv_writer.dart';
import '../utils/date_formatter.dart';

/// Export CSV du catalogue (articles, clients, fournisseurs) pour
/// sauvegarde externe ou consultation dans un tableur.
///
/// Génération déportée sur un isolate séparé via [compute] : sur un
/// catalogue de plusieurs milliers d'entrées, construire le CSV ligne
/// par ligne prend un temps non négligeable et gèlerait l'UI si on le
/// faisait sur l'isolate principal (même approche que
/// InventoryExportService).
abstract final class CatalogExportService {
  static const entetesArticles = [
    'Code',
    'Désignation',
    'Catégorie',
    'Prix achat',
    'Prix vente',
    'Stock minimum',
    'Stock total',
    'Taux TVA (%)',
    'Actif',
    'Date de création',
  ];

  static Future<String> articlesCsv(List<ArticleEntity> articles) =>
      compute(_articlesCsvSync, articles);

  static String _articlesCsvSync(List<ArticleEntity> articles) {
    return CsvWriter.build(entetesArticles, [
      for (final a in articles)
        [
          a.code,
          a.nom,
          a.categorieNom ?? '',
          a.prixAchat,
          a.prixVente,
          a.stockMinimum,
          a.stockTotal,
          a.tauxTvaDefaut,
          a.actif ? 'Oui' : 'Non',
          DateFormatter.formatDate(a.dateCreation),
        ],
    ]);
  }

  static const entetesClients = [
    'Nom',
    'Téléphone',
    'Adresse',
    'NIF',
    'Dette totale',
    'Date de création',
  ];

  static Future<String> clientsCsv(List<ClientEntity> clients) =>
      compute(_clientsCsvSync, clients);

  static String _clientsCsvSync(List<ClientEntity> clients) {
    return CsvWriter.build(entetesClients, [
      for (final c in clients)
        [
          c.nom,
          c.telephone ?? '',
          c.adresse ?? '',
          c.nif ?? '',
          c.detteTotale,
          DateFormatter.formatDate(c.dateCreation),
        ],
    ]);
  }

  static const entetesSuppliers = [
    'Nom',
    'Téléphone',
    'Adresse',
    'Dette totale',
    'Date de création',
  ];

  static Future<String> suppliersCsv(List<SupplierEntity> suppliers) =>
      compute(_suppliersCsvSync, suppliers);

  static String _suppliersCsvSync(List<SupplierEntity> suppliers) {
    return CsvWriter.build(entetesSuppliers, [
      for (final s in suppliers)
        [
          s.nom,
          s.telephone ?? '',
          s.adresse ?? '',
          s.detteTotale,
          DateFormatter.formatDate(s.dateCreation),
        ],
    ]);
  }

  /// Nom de fichier suggéré, ex: "articles_2026-09-18".
  static String nomFichierSuggere(String prefixe) {
    final date = DateFormatter.formatDate(DateTime.now()).replaceAll('/', '-');
    return '${prefixe}_$date';
  }
}
