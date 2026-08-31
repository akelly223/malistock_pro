import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../domain/entities/inventory.dart';
import '../utils/date_formatter.dart';

/// Génère la feuille de comptage d'un inventaire (colonnes Code,
/// Désignation, Catégorie, Magasin, Stock théorique, Stock physique
/// et Écart vides, Observation vide) en Excel (.xlsx) ou CSV, prête à
/// être imprimée ou remplie sur le poste du commerçant puis
/// réimportée telle quelle par [InventoryImportService].
abstract final class InventoryExportService {
  static const List<String> entetes = [
    'Code article',
    'Désignation',
    'Catégorie',
    'Magasin',
    'Stock théorique',
    'Stock physique',
    'Écart',
    'Observation',
  ];

  static List<Object?> _ligneBrute(
      InventoryEntity inventaire, InventoryLineEntity ligne) {
    return [
      ligne.articleCode,
      ligne.articleNom,
      ligne.categorieNom ?? '',
      inventaire.storeNom,
      ligne.stockTheorique,
      null, // Stock physique — à remplir par le commerçant
      null, // Écart — calculé automatiquement à l'import
      null, // Observation — libre
    ];
  }

  /// Construit les octets d'un fichier .xlsx prêt à écrire sur disque.
  ///
  /// Génération déportée sur un isolate séparé via [compute] : sur un
  /// catalogue de plusieurs milliers d'articles, construire la feuille
  /// ligne par ligne prend un temps non négligeable et gèlerait l'UI
  /// si on le faisait sur l'isolate principal.
  static Future<List<int>> xlsxBytes(
    InventoryEntity inventaire,
    List<InventoryLineEntity> lignes,
  ) {
    return compute(
        _xlsxBytesSync, (inventaire: inventaire, lignes: lignes));
  }

  static List<int> _xlsxBytesSync(
      ({InventoryEntity inventaire, List<InventoryLineEntity> lignes}) args) {
    final excel = Excel.createExcel();
    const nomFeuille = 'Inventaire';
    final ancienNom = excel.getDefaultSheet();
    if (ancienNom != null && ancienNom != nomFeuille) {
      excel.rename(ancienNom, nomFeuille);
    }
    final sheet = excel[nomFeuille];

    sheet.appendRow(entetes.map((e) => TextCellValue(e)).toList());

    for (final ligne in args.lignes) {
      final brute = _ligneBrute(args.inventaire, ligne);
      sheet.appendRow(brute.map(_versCellValue).toList());
    }

    return excel.encode() ?? <int>[];
  }

  static CellValue? _versCellValue(Object? valeur) {
    if (valeur == null) return null;
    if (valeur is double) return DoubleCellValue(valeur);
    if (valeur is int) return IntCellValue(valeur);
    return TextCellValue(valeur.toString());
  }

  /// Construit le contenu texte d'un fichier CSV (séparateur `;`,
  /// convention Excel FR déjà utilisée par le parseur d'import).
  ///
  /// Comme [xlsxBytes], déporté sur un isolate séparé pour rester
  /// fluide sur un gros catalogue.
  static Future<String> csvContent(
    InventoryEntity inventaire,
    List<InventoryLineEntity> lignes,
  ) {
    return compute(
        _csvContentSync, (inventaire: inventaire, lignes: lignes));
  }

  static String _csvContentSync(
      ({InventoryEntity inventaire, List<InventoryLineEntity> lignes}) args) {
    final buffer = StringBuffer();
    buffer.writeln(entetes.map(_champCsv).join(';'));
    for (final ligne in args.lignes) {
      final brute = _ligneBrute(args.inventaire, ligne);
      buffer.writeln(brute.map((v) => _champCsv(v?.toString() ?? '')).join(';'));
    }
    return buffer.toString();
  }

  static String _champCsv(String valeur) {
    if (valeur.contains(';') || valeur.contains('"') || valeur.contains('\n')) {
      return '"${valeur.replaceAll('"', '""')}"';
    }
    return valeur;
  }

  /// Nom de fichier suggéré, ex: "INV-2026-0001_2026-07-08".
  static String nomFichierSuggere(InventoryEntity inventaire) {
    final date = DateFormatter.formatDate(inventaire.dateCreation)
        .replaceAll('/', '-');
    return '${inventaire.numero}_$date';
  }
}
