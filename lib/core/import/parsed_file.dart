/// Résultat du parsing d'un fichier (avant le mapping des colonnes).
class ParsedFile {
  final String fileName;
  final List<String> headers;
  /// Lignes de données (sans l'en-tête). Chaque ligne est une liste de valeurs brutes.
  final List<List<String>> rows;

  const ParsedFile({
    required this.fileName,
    required this.headers,
    required this.rows,
  });

  int get totalRows => rows.length;
}
