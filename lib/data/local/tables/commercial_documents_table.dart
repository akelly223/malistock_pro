import 'package:drift/drift.dart';
import 'clients_table.dart';
import 'stores_table.dart';
import 'users_table.dart';

/// Table unifiée de toutes les pièces commerciales (modèle Sage PIECE).
///
/// Un seul enregistrement par document, quel que soit son type.
/// Les transformations (proforma → BC → BL → facture) créent de nouveaux
/// enregistrements avec [parentDocumentId] pointant vers la source.
class CommercialDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro affiché, ex: PRO-2026-0001, BL-2026-0003, FAC-2026-0010.
  TextColumn get numero => text().withLength(min: 1, max: 50).unique()();

  /// Type de la pièce. Valeurs possibles :
  /// 'proforma' | 'bon_commande' | 'preparation_livraison' |
  /// 'bon_livraison' | 'bon_retour' | 'avoir' |
  /// 'facture' | 'facture_comptabilisee'
  TextColumn get type => text()();

  /// Cycle de vie du document.
  /// 'brouillon' → modifiable
  /// 'valide'    → verrouillé (impact stock possible)
  /// 'transforme'→ utilisé pour créer la pièce suivante
  /// 'annule'    → sans effet comptable
  TextColumn get statut => text().withDefault(const Constant('brouillon'))();

  /// NULL = vente au comptoir sans client enregistré.
  IntColumn get clientId => integer().nullable().references(Clients, #id)();

  IntColumn get storeId => integer().references(Stores, #id)();

  /// Date visible sur le document imprimé.
  DateTimeColumn get dateDocument => dateTime()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get dateModification => dateTime().nullable()();

  /// Renseigné quand statut passe à 'valide'.
  DateTimeColumn get dateValidation => dateTime().nullable()();

  /// Échéance de paiement pour les factures.
  DateTimeColumn get dateEcheance => dateTime().nullable()();

  IntColumn get createdById => integer().nullable().references(Users, #id)();
  IntColumn get updatedById => integer().nullable().references(Users, #id)();

  /// Dénormalisé pour l'audit (nom conservé même si l'utilisateur est supprimé).
  TextColumn get createdByNom => text().nullable()();
  TextColumn get updatedByNom => text().nullable()();

  // ── Totaux (recalculés à chaque modification des lignes) ──────────────

  RealColumn get totalHt => real().withDefault(const Constant(0))();
  RealColumn get totalTva => real().withDefault(const Constant(0))();
  RealColumn get totalTtc => real().withDefault(const Constant(0))();
  RealColumn get remiseGlobalePct => real().withDefault(const Constant(0))();

  // ── Paiement (pour factures et avoirs) ───────────────────────────────

  RealColumn get montantPaye => real().withDefault(const Constant(0))();

  /// 'non_paye' | 'partiel' | 'paye'
  TextColumn get statutPaiement =>
      text().withDefault(const Constant('non_paye'))();

  // ── Chaîne de transformation ─────────────────────────────────────────

  /// Pointe vers le document source (ex: un BL pointe vers son BC).
  /// Relation gérée en code ; pas de FK déclarée pour éviter la circularité
  /// dans la définition Drift.
  IntColumn get parentDocumentId => integer().nullable()();

  TextColumn get notes => text().nullable()();

  /// N° BC client, référence Sage, etc.
  TextColumn get referenceExterne => text().nullable()();

  /// Ex: '30 jours fin de mois', 'À réception'.
  TextColumn get conditionsReglement => text().nullable()();
}
