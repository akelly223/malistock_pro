import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/document_counters_table.dart';

part 'document_counters_dao.g.dart';

@DriftAccessor(tables: [DocumentCounters])
class DocumentCountersDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentCountersDaoMixin {
  DocumentCountersDao(super.db);

  /// Génère le prochain numéro pour un préfixe donné (ex: "FAC", "ACH",
  /// "DEV") sur l'année en cours, ex: FAC-2026-0001.
  ///
  /// Incrémentation atomique : lecture et écriture du compteur dans
  /// la même transaction, ce qui élimine la course de concurrence
  /// possible avec l'ancienne approche `COUNT(*) + 1` (deux ventes
  /// validées en même temps pouvaient lire le même compte avant que
  /// l'une des deux insertions ne soit committée). Le compteur n'est
  /// jamais décrémenté, donc un numéro supprimé n'est jamais réutilisé.
  Future<String> genererProchainNumero(String prefixeDocument) async {
    final annee = DateTime.now().year;
    final cle = '$prefixeDocument-$annee';

    return transaction(() async {
      final existant = await (select(documentCounters)
            ..where((c) => c.cle.equals(cle)))
          .getSingleOrNull();

      final prochainNumero = (existant?.dernierNumero ?? 0) + 1;

      if (existant == null) {
        await into(documentCounters).insert(DocumentCountersCompanion.insert(
          cle: cle,
          dernierNumero: Value(prochainNumero),
        ));
      } else {
        await (update(documentCounters)..where((c) => c.cle.equals(cle)))
            .write(DocumentCountersCompanion(
          dernierNumero: Value(prochainNumero),
        ));
      }

      return '$cle-${prochainNumero.toString().padLeft(4, '0')}';
    });
  }
}
