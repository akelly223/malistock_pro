import 'dart:convert';
import 'dart:io';

import '../../domain/entities/article.dart';
import '../../domain/repositories/article_repository.dart';

/// Une ligne analysée depuis le fichier d'import.
class ArticleImportRow {
  final int lineNumber;
  final String code;
  final String famille;
  final String nom;
  final double prixAchat;
  final double prixVente;
  final double? stockInitial;

  const ArticleImportRow({
    required this.lineNumber,
    required this.code,
    required this.famille,
    required this.nom,
    required this.prixAchat,
    required this.prixVente,
    this.stockInitial,
  });
}

/// Résumé après un import.
class ArticleImportResult {
  final int importes;
  final int misAJour;
  final int ignores;
  final List<String> erreurs;

  const ArticleImportResult({
    required this.importes,
    required this.misAJour,
    required this.ignores,
    required this.erreurs,
  });
}

enum DoublonStrategie { ignorer, mettreAJour, demanderChaque }

class ArticleImportService {
  final ArticleRepository _repo;

  const ArticleImportService(this._repo);

  /// Lit un fichier TXT/CSV en essayant UTF-8 puis Latin-1 (Windows-1252).
  static Future<String> lireFichier(String filePath) async {
    final file = File(filePath);
    try {
      return await file.readAsString(encoding: utf8);
    } catch (_) {
      return await file.readAsString(encoding: latin1);
    }
  }

  /// Analyse le contenu d'un fichier TXT ou CSV.
  ///
  /// Format attendu (Sage Gestion Commerciale) :
  ///   CodeArticle [tab] Famille [tab] Désignation [tab] PrixAchat [tab] PrixVente
  ///
  /// Également accepté :
  ///   - Séparateur point-virgule (CSV)
  ///   - 4 colonnes sans famille : CodeArticle | Désignation | PrixAchat | PrixVente
  ///   - 6 colonnes avec stock  : CodeArticle | Famille | Désignation | PrixAchat | PrixVente | Stock
  static List<ArticleImportRow> parseContent(String content) {
    final rows = <ArticleImportRow>[];
    final lines = content.split(RegExp(r'\r?\n'));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitLine(line);
      if (cols.length < 4) continue;

      String code, famille, nom;
      double? prixAchat, prixVente;
      double? stockInitial;

      if (cols.length >= 5) {
        code = cols[0].trim();
        famille = cols[1].trim();
        nom = cols[2].trim();
        prixAchat = _parsePrice(cols[3]);
        prixVente = _parsePrice(cols[4]);
        if (cols.length >= 6) stockInitial = _parsePrice(cols[5]);
      } else {
        // 4 colonnes : code | désignation | PA | PV
        code = cols[0].trim();
        famille = '';
        nom = cols[1].trim();
        prixAchat = _parsePrice(cols[2]);
        prixVente = _parsePrice(cols[3]);
      }

      if (code.isEmpty || nom.isEmpty) continue;
      if (prixAchat == null || prixVente == null) continue;

      rows.add(ArticleImportRow(
        lineNumber: i + 1,
        code: code,
        famille: famille,
        nom: nom,
        prixAchat: prixAchat,
        prixVente: prixVente,
        stockInitial: stockInitial,
      ));
    }

    return rows;
  }

  static List<String> _splitLine(String line) {
    if (line.contains('\t')) return line.split('\t');
    if (line.contains(';')) return line.split(';');
    return line.split(',');
  }

  /// Convertit une valeur prix Sage ("7000,000000" ou "7000.000000") en double.
  static double? _parsePrice(String s) {
    final cleaned = s.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Retourne les codes qui correspondent à des articles déjà en base.
  Future<Set<String>> trouverDoublons(List<ArticleImportRow> rows) async {
    final doublons = <String>{};
    for (final row in rows) {
      final existant = await _repo.getArticleByCode(row.code);
      if (existant != null) doublons.add(row.code);
    }
    return doublons;
  }

  Future<ArticleImportResult> importerArticles({
    required List<ArticleImportRow> rows,
    required DoublonStrategie doublonStrategie,
    required bool importerStock,
    int? storeId,
    Map<String, DoublonStrategie>? strategieParArticle,
    void Function(int done, int total)? onProgress,
  }) async {
    int importes = 0;
    int misAJour = 0;
    int ignores = 0;
    final erreurs = <String>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];

      if (i % 5 == 0 || i == rows.length - 1) {
        onProgress?.call(i, rows.length);
      }

      try {
        final existant = await _repo.getArticleByCode(row.code);

        if (existant == null) {
          final id = await _repo.createArticle(
            code: row.code,
            nom: row.nom,
            categorieId: null,
            prixAchat: row.prixAchat,
            prixVente: row.prixVente,
            stockMinimum: 0,
          );
          if (importerStock &&
              storeId != null &&
              row.stockInitial != null &&
              row.stockInitial! > 0) {
            await _repo.adjustStock(
              articleId: id,
              storeId: storeId,
              delta: row.stockInitial!,
            );
          }
          importes++;
        } else {
          final strategie =
              strategieParArticle?[row.code] ?? doublonStrategie;

          if (strategie == DoublonStrategie.mettreAJour) {
            await _repo.updateArticle(ArticleEntity(
              id: existant.id,
              code: existant.code,
              nom: row.nom,
              categorieId: existant.categorieId,
              categorieNom: existant.categorieNom,
              prixAchat: row.prixAchat,
              prixVente: row.prixVente,
              stockMinimum: existant.stockMinimum,
              stockTotal: existant.stockTotal,
              dateCreation: existant.dateCreation,
              actif: existant.actif,
            ));
            misAJour++;
          } else {
            ignores++;
          }
        }
      } catch (e) {
        erreurs.add('Ligne ${row.lineNumber} (${row.code}) : ${e.toString()}');
      }
    }

    onProgress?.call(rows.length, rows.length);

    return ArticleImportResult(
      importes: importes,
      misAJour: misAJour,
      ignores: ignores,
      erreurs: erreurs,
    );
  }
}
