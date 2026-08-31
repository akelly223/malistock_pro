import 'import_field.dart';
import 'import_result.dart';

/// Interface que chaque exécuteur d'import doit implémenter.
/// Découple la logique métier (enregistrement en BDD) du wizard UI.
abstract class ImportExecutor {
  /// Identifiant de chaque ligne (ex: code article, nom client).
  /// Utilisé pour la détection des doublons et le rapport d'erreurs.
  String rowIdentifier(Map<ImportField, String> row);

  /// Retourne les identifiants des lignes qui correspondent à des
  /// enregistrements déjà existants en base.
  Future<Set<String>> findDuplicates(List<Map<ImportField, String>> rows);

  /// Exécute l'import. Appelle [onProgress] tous les N enregistrements.
  Future<ImportResult> execute({
    required List<Map<ImportField, String>> rows,
    required DuplicateStrategy globalStrategy,
    Map<String, DuplicateStrategy>? strategyPerItem,
    int? targetStoreId,
    void Function(int done, int total)? onProgress,
  });

  /// Indique si cet exécuteur supporte la sélection d'un magasin
  /// (uniquement pour les articles avec stock).
  bool get requiresStoreSelection => false;
}
