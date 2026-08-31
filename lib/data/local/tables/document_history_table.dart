import 'package:drift/drift.dart';
import 'commercial_documents_table.dart';
import 'users_table.dart';

/// Journal d'audit des pièces commerciales.
///
/// Chaque action (création, validation, transformation, annulation,
/// paiement) génère une entrée immuable dans cette table.
///
/// Le nom de la classe de données générée est [DocumentHistoryRecord]
/// (défini via @DataClassName pour éviter le conflit avec la classe table).
@DataClassName('DocumentHistoryRecord')
class DocumentHistories extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get documentId =>
      integer().references(CommercialDocuments, #id)();

  /// 'cree' | 'modifie' | 'valide' | 'transforme' |
  /// 'annule' | 'paiement_ajoute' | 'comptabilise'
  TextColumn get action => text()();

  TextColumn get ancienStatut => text().nullable()();
  TextColumn get nouveauStatut => text().nullable()();

  /// Message lisible, ex: 'Transformé en BL-2026-0003'.
  TextColumn get description => text().nullable()();

  IntColumn get userId => integer().nullable().references(Users, #id)();

  /// Dénormalisé pour la lecture d'audit (stable même si l'user est supprimé).
  TextColumn get userNom => text().nullable()();

  DateTimeColumn get dateAction =>
      dateTime().withDefault(currentDateAndTime)();
}
