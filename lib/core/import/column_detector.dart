import 'import_field.dart';

/// Détecte automatiquement la correspondance entre les colonnes
/// d'un fichier et les champs cibles, par correspondance floue.
abstract final class ColumnDetector {
  /// Retourne un mapping `index colonne → ImportField` pour les colonnes
  /// dont la correspondance a été trouvée automatiquement.
  ///
  /// Un champ ne peut être assigné qu'à une seule colonne (la première
  /// correspondance trouvée). Les colonnes sans correspondance ont `null`.
  static Map<int, ImportField?> detect(
    List<String> headers,
    List<ImportField> availableFields,
  ) {
    final mappings = <int, ImportField?>{};
    final alreadyMapped = <ImportField>{};

    for (int i = 0; i < headers.length; i++) {
      final normalized = normalizeForDetection(headers[i]);
      if (normalized.isEmpty) {
        mappings[i] = null;
        continue;
      }

      ImportField? best;
      for (final field in availableFields) {
        if (alreadyMapped.contains(field)) continue;
        final meta = importFieldMeta[field]!;
        if (meta.aliases.any((alias) => alias == normalized)) {
          best = field;
          break;
        }
      }

      // Deuxième passe : correspondance partielle (contient l'alias)
      if (best == null) {
        for (final field in availableFields) {
          if (alreadyMapped.contains(field)) continue;
          final meta = importFieldMeta[field]!;
          if (meta.aliases
              .any((a) => normalized.contains(a) || a.contains(normalized))) {
            best = field;
            break;
          }
        }
      }

      mappings[i] = best;
      if (best != null) alreadyMapped.add(best);
    }

    return mappings;
  }
}
