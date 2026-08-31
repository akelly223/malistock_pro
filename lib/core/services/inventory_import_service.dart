import '../import/file_parser.dart';
import '../import/import_field.dart' show normalizeForDetection;
import '../../domain/entities/inventory.dart';

/// Résultat du parsing d'un fichier de comptage réimporté, avant
/// rapprochement avec les lignes de l'inventaire (fait par
/// InventoryRepository.importerComptage).
class InventoryParseResult {
  final List<InventoryCountRow> rows;
  final List<String> lignesIgnorees;

  const InventoryParseResult({
    required this.rows,
    required this.lignesIgnorees,
  });
}

/// Lit le fichier Excel/CSV/TXT complété par le commerçant (feuille
/// générée par [InventoryExportService], imprimée ou remplie
/// directement sur son poste) et en extrait Code / Stock physique /
/// Observation. La détection des colonnes est tolérante (accents,
/// casse, alias) puisque le commerçant peut réorganiser ou renommer
/// légèrement les colonnes dans Excel.
abstract final class InventoryImportService {
  static const _aliasCode = [
    'codearticle', 'code', 'refarticle', 'reference', 'ref', 'sku',
  ];
  static const _aliasStockPhysique = [
    'stockphysique', 'physique', 'quantitephysique', 'comptage',
    'qtephysique', 'stockreel', 'stockcompte',
  ];
  static const _aliasObservation = [
    'observation', 'observations', 'commentaire', 'remarque', 'note',
  ];

  static Future<InventoryParseResult> parseFichier(String filePath) async {
    final parsed = await FileParser.parse(filePath);
    final headersNormalises =
        parsed.headers.map(normalizeForDetection).toList();

    int? trouverColonne(List<String> alias) {
      for (int i = 0; i < headersNormalises.length; i++) {
        if (alias.contains(headersNormalises[i])) return i;
      }
      return null;
    }

    final idxCode = trouverColonne(_aliasCode);
    final idxPhysique = trouverColonne(_aliasStockPhysique);
    final idxObservation = trouverColonne(_aliasObservation);

    if (idxCode == null || idxPhysique == null) {
      throw Exception(
        'Colonnes non reconnues : le fichier doit contenir au minimum '
        'une colonne "Code article" et une colonne "Stock physique".',
      );
    }

    final rows = <InventoryCountRow>[];
    final ignorees = <String>[];

    for (int i = 0; i < parsed.rows.length; i++) {
      final row = parsed.rows[i];
      final code = idxCode < row.length ? row[idxCode].trim() : '';
      final brutPhysique =
          idxPhysique < row.length ? row[idxPhysique].trim() : '';
      final observation = idxObservation != null && idxObservation < row.length
          ? row[idxObservation].trim()
          : '';

      if (code.isEmpty) continue;
      // Pas encore compté sur cette ligne : on la laisse simplement de
      // côté, ce n'est pas une erreur.
      if (brutPhysique.isEmpty) continue;

      final physique = double.tryParse(brutPhysique.replaceAll(',', '.'));
      if (physique == null) {
        ignorees.add(
            'Ligne ${i + 2} ($code) : stock physique illisible ("$brutPhysique")');
        continue;
      }

      rows.add(InventoryCountRow(
        code: code,
        stockPhysique: physique,
        observation: observation.isEmpty ? null : observation,
      ));
    }

    return InventoryParseResult(rows: rows, lignesIgnorees: ignorees);
  }
}
