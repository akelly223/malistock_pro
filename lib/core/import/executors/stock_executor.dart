import '../../../domain/repositories/article_repository.dart';
import '../import_executor.dart';
import '../import_field.dart';
import '../import_result.dart';

/// Exécuteur d'import de stock.
///
/// Met à jour les quantités en stock pour des articles existants.
/// Les articles introuvables sont signalés dans le rapport d'erreurs.
class StockImportExecutor implements ImportExecutor {
  final ArticleRepository _repo;
  final StockImportMode mode;

  const StockImportExecutor(this._repo, {this.mode = StockImportMode.ajouter});

  @override
  bool get requiresStoreSelection => true;

  @override
  String rowIdentifier(Map<ImportField, String> row) =>
      row[ImportField.codeArticle] ?? '';

  /// Pour l'import de stock, les "doublons" sont les articles introuvables
  /// (ils seront signalés en erreur). Retourne un ensemble vide — la détection
  /// se fait ligne par ligne dans [execute].
  @override
  Future<Set<String>> findDuplicates(
          List<Map<ImportField, String>> rows) async =>
      {};

  @override
  Future<ImportResult> execute({
    required List<Map<ImportField, String>> rows,
    required DuplicateStrategy globalStrategy,
    Map<String, DuplicateStrategy>? strategyPerItem,
    int? targetStoreId,
    void Function(int done, int total)? onProgress,
  }) async {
    if (targetStoreId == null) {
      return const ImportResult(
        created: 0,
        updated: 0,
        ignored: 0,
        errors: [
          ImportError(
            rowNumber: 0,
            message: 'Aucun magasin sélectionné.',
          )
        ],
      );
    }

    int updated = 0, ignored = 0;
    final errors = <ImportError>[];

    for (int i = 0; i < rows.length; i++) {
      if (i % 10 == 0 || i == rows.length - 1) {
        onProgress?.call(i, rows.length);
        await Future.delayed(Duration.zero);
      }

      final row = rows[i];
      final rowNum = i + 2;
      final code = row[ImportField.codeArticle]?.trim() ?? '';

      if (code.isEmpty) {
        errors.add(ImportError(rowNumber: rowNum, message: 'Code article manquant'));
        continue;
      }

      final qteRaw = row[ImportField.stockInitial]?.trim() ?? '';
      final qte = _parseDouble(qteRaw);
      if (qte == null) {
        errors.add(ImportError(
          rowNumber: rowNum,
          identifier: code,
          message: 'Quantité invalide : "$qteRaw"',
        ));
        continue;
      }

      try {
        final article = await _repo.getArticleByCode(code);

        if (article == null) {
          errors.add(ImportError(
            rowNumber: rowNum,
            identifier: code,
            message: 'Article introuvable dans MaliStock Pro',
          ));
          continue;
        }

        final double delta;
        if (mode == StockImportMode.remplacer) {
          final stockActuel =
              await _repo.getStockInStore(article.id, targetStoreId);
          delta = qte - stockActuel;
        } else {
          delta = qte;
        }

        // Ne rien faire si le delta est nul (évite une écriture inutile)
        if (delta != 0) {
          await _repo.adjustStock(
            articleId: article.id,
            storeId: targetStoreId,
            delta: delta,
          );
        }
        updated++;
      } catch (e) {
        errors.add(ImportError(
          rowNumber: rowNum,
          identifier: code,
          message: e.toString(),
        ));
      }
    }

    onProgress?.call(rows.length, rows.length);
    return ImportResult(
      created: 0,
      updated: updated,
      ignored: ignored,
      errors: errors,
    );
  }

  static double? _parseDouble(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));
  }
}
