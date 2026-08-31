import 'package:drift/drift.dart';
import 'commercial_documents_table.dart';
import 'users_table.dart';

/// Paiements rattachés aux pièces commerciales V2.
///
/// Un document peut recevoir plusieurs paiements partiels.
/// Si [modePaiement] vaut 'avoir', [avoirDocumentId] pointe vers
/// l'avoir financier utilisé pour ce règlement.
class DocumentPayments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get documentId =>
      integer().references(CommercialDocuments, #id)();

  RealColumn get montant => real()();

  DateTimeColumn get datePaiement => dateTime()();

  /// 'especes' | 'cheque' | 'virement' | 'mobile_money' | 'avoir'
  TextColumn get modePaiement =>
      text().withDefault(const Constant('especes'))();

  /// N° chèque, référence mobile money, etc.
  TextColumn get reference => text().nullable()();

  /// Si mode = 'avoir', pointe vers l'avoir utilisé pour ce règlement.
  IntColumn get avoirDocumentId =>
      integer().nullable().references(CommercialDocuments, #id)();

  IntColumn get createdById =>
      integer().nullable().references(Users, #id)();

  /// Dénormalisé pour l'audit.
  TextColumn get createdByNom => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  /// Numéro du reçu de paiement généré pour ce règlement (ex: REC-2026-0001).
  TextColumn get numeroRecu => text().nullable()();
}
