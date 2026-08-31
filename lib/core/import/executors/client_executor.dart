import '../../../domain/repositories/client_repository.dart';
import '../import_executor.dart';
import '../import_field.dart';
import '../import_result.dart';

class ClientImportExecutor implements ImportExecutor {
  final ClientRepository _repo;

  const ClientImportExecutor(this._repo);

  @override
  bool get requiresStoreSelection => false;

  @override
  String rowIdentifier(Map<ImportField, String> row) =>
      row[ImportField.nom] ?? '';

  @override
  Future<Set<String>> findDuplicates(
      List<Map<ImportField, String>> rows) async {
    final doublons = <String>{};
    for (final row in rows) {
      final nom = row[ImportField.nom]?.trim();
      if (nom == null || nom.isEmpty) continue;
      final tel = row[ImportField.telephone]?.trim();
      final existant = await _repo.verifierDoublon(nom: nom, telephone: tel);
      if (existant != null) doublons.add(nom);
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
        await Future.delayed(Duration.zero);
      }

      final row = rows[i];
      final rowNum = i + 2;
      final nom = row[ImportField.nom]?.trim() ?? '';

      if (nom.isEmpty) {
        errors.add(ImportError(rowNumber: rowNum, message: 'Nom manquant'));
        continue;
      }

      final tel = _optionnel(row[ImportField.telephone]);
      final adresse = _optionnel(row[ImportField.adresse]);

      try {
        final existant =
            await _repo.verifierDoublon(nom: nom, telephone: tel);

        if (existant == null) {
          await _repo.createClient(
            nom: nom,
            telephone: tel,
            adresse: adresse,
          );
          created++;
        } else {
          final strategie = strategyPerItem?[nom] ?? globalStrategy;
          if (strategie == DuplicateStrategy.mettreAJour) {
            await _repo.updateClient(existant.copyWithEdit(
              nom: nom,
              telephone: tel ?? existant.telephone,
              adresse: adresse ?? existant.adresse,
            ));
            updated++;
          } else {
            ignored++;
          }
        }
      } catch (e) {
        errors.add(ImportError(
            rowNumber: rowNum, identifier: nom, message: e.toString()));
      }
    }

    onProgress?.call(rows.length, rows.length);
    return ImportResult(
        created: created, updated: updated, ignored: ignored, errors: errors);
  }

  String? _optionnel(String? s) {
    final v = s?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
