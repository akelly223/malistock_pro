import '../../../domain/entities/article.dart';
import '../../../domain/repositories/article_repository.dart';
import '../import_executor.dart';
import '../import_field.dart';
import '../import_result.dart';

class ArticleImportExecutor implements ImportExecutor {
  final ArticleRepository _repo;
  final bool importerAvecStock;

  const ArticleImportExecutor(this._repo, {this.importerAvecStock = false});

  @override
  bool get requiresStoreSelection => true;

  @override
  String rowIdentifier(Map<ImportField, String> row) =>
      row[ImportField.codeArticle] ?? '';

  @override
  Future<Set<String>> findDuplicates(
      List<Map<ImportField, String>> rows) async {
    final doublons = <String>{};
    for (final row in rows) {
      final code = row[ImportField.codeArticle]?.trim();
      if (code == null || code.isEmpty) continue;
      final existant = await _repo.getArticleByCode(code);
      if (existant != null) doublons.add(code);
    }
    return doublons;
  }

  @override
  Future<ImportResult> execute({
    required List<Map<ImportField, String>> rows,
    required DuplicateStrategy globalStrategy,
    Map<String, DuplicateStrategy>? strategyPerItem,
    int? targetStoreId,
    void Function(int done, int total)? onProgress,
  }) async {
    int created = 0, updated = 0, ignored = 0;
    final errors = <ImportError>[];

    for (int i = 0; i < rows.length; i++) {
      if (i % 10 == 0 || i == rows.length - 1) {
        onProgress?.call(i, rows.length);
        // Yield pour ne pas bloquer l'UI
        await Future.delayed(Duration.zero);
      }

      final row = rows[i];
      final rowNum = i + 2; // +2 : ligne 1 = en-tête, lignes numérotées à partir de 2
      final code = row[ImportField.codeArticle]?.trim() ?? '';
      final nom = row[ImportField.designation]?.trim() ?? '';

      if (code.isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          message: 'Code article manquant',
        ));
        continue;
      }
      if (nom.isEmpty) {
        errors.add(ImportError(
          rowNumber: rowNum,
          identifier: code,
          message: 'Désignation manquante',
        ));
        continue;
      }

      final pvRaw = row[ImportField.prixVente]?.trim() ?? '';
      final prixVente = _parseDouble(pvRaw);
      if (prixVente == null) {
        errors.add(ImportError(
          rowNumber: rowNum,
          identifier: code,
          message: 'Prix de vente invalide : "$pvRaw"',
        ));
        continue;
      }

      final prixAchat = _parseDouble(row[ImportField.prixAchat]?.trim()) ?? 0.0;
      final stockInitial =
          _parseDouble(row[ImportField.stockInitial]?.trim()) ?? 0.0;
      final stockMin =
          _parseDouble(row[ImportField.stockMinimum]?.trim()) ?? 0.0;

      try {
        final existant = await _repo.getArticleByCode(code);

        if (existant == null) {
          final id = await _repo.createArticle(
            code: code,
            nom: nom,
            categorieId: null,
            prixAchat: prixAchat,
            prixVente: prixVente,
            stockMinimum: stockMin,
          );

          if (importerAvecStock &&
              targetStoreId != null &&
              stockInitial > 0) {
            await _repo.adjustStock(
              articleId: id,
              storeId: targetStoreId,
              delta: stockInitial,
            );
          }
          created++;
        } else {
          final strategie = strategyPerItem?[code] ?? globalStrategy;
          if (strategie == DuplicateStrategy.mettreAJour) {
            await _repo.updateArticle(ArticleEntity(
              id: existant.id,
              code: existant.code,
              nom: nom,
              categorieId: existant.categorieId,
              categorieNom: existant.categorieNom,
              prixAchat: prixAchat,
              prixVente: prixVente,
              stockMinimum: stockMin > 0 ? stockMin : existant.stockMinimum,
              stockTotal: existant.stockTotal,
              dateCreation: existant.dateCreation,
              actif: existant.actif,
            ));
            updated++;
          } else {
            ignored++;
          }
        }
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
      created: created,
      updated: updated,
      ignored: ignored,
      errors: errors,
    );
  }

  static double? _parseDouble(String? s) {
    if (s == null || s.isEmpty) return null;
    final cleaned = s.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
