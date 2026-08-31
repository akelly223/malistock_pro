/// Résultat complet d'un import.
class ImportResult {
  final int created;
  final int updated;
  final int ignored;
  final List<ImportError> errors;

  const ImportResult({
    required this.created,
    required this.updated,
    required this.ignored,
    required this.errors,
  });

  int get total => created + updated + ignored + errors.length;

  String get errorReport {
    if (errors.isEmpty) return '';
    final buf = StringBuffer('Rapport des erreurs d\'import\n');
    buf.writeln('=' * 40);
    for (final e in errors) {
      buf.writeln('Ligne ${e.rowNumber}${e.identifier != null ? ' (${e.identifier})' : ''}: ${e.message}');
    }
    return buf.toString();
  }
}

class ImportError {
  final int rowNumber;
  final String? identifier;
  final String message;

  const ImportError({
    required this.rowNumber,
    this.identifier,
    required this.message,
  });
}

/// Stratégie pour les doublons.
enum DuplicateStrategy { ignorer, mettreAJour, demanderChaque }

/// Mode d'ajustement lors de l'import de stock.
enum StockImportMode {
  /// Ajoute la quantité importée au stock existant.
  ajouter,

  /// Remplace le stock existant par la quantité importée.
  remplacer,
}
