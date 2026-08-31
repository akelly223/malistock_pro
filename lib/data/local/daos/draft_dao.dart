import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/drafts_table.dart';

part 'draft_dao.g.dart';

@DriftAccessor(tables: [Drafts])
class DraftDao extends DatabaseAccessor<AppDatabase> with _$DraftDaoMixin {
  DraftDao(super.db);

  Future<void> saveDraft(String type, String donnees) =>
      into(drafts).insertOnConflictUpdate(DraftsCompanion.insert(
        type: type,
        donnees: donnees,
        dateSauvegarde: Value(DateTime.now()),
      ));

  Future<Draft?> getDraft(String type) =>
      (select(drafts)..where((d) => d.type.equals(type))).getSingleOrNull();

  Future<List<Draft>> getAllDrafts() => select(drafts).get();

  Future<void> deleteDraft(String type) =>
      (delete(drafts)..where((d) => d.type.equals(type))).go();

  Future<void> deleteAllDrafts() => delete(drafts).go();
}
