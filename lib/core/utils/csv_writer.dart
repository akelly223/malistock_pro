/// Construit le contenu texte d'un fichier CSV (séparateur `;`, convention
/// Excel FR), en échappant les valeurs contenant `;`, `"` ou un retour à
/// la ligne.
abstract final class CsvWriter {
  static String build(List<String> entetes, List<List<Object?>> lignes) {
    final buffer = StringBuffer();
    buffer.writeln(entetes.map(_champ).join(';'));
    for (final ligne in lignes) {
      buffer.writeln(ligne.map(_champ).join(';'));
    }
    return buffer.toString();
  }

  static String _champ(Object? valeur) {
    final texte = valeur?.toString() ?? '';
    if (texte.contains(';') || texte.contains('"') || texte.contains('\n')) {
      return '"${texte.replaceAll('"', '""')}"';
    }
    return texte;
  }
}
