import 'package:drift/drift.dart';

/// Table des clients.
///
/// [detteTotale] est une valeur dénormalisée recalculée à chaque
/// facture / paiement pour affichage rapide dans la liste des clients
/// débiteurs (module Dettes clients).
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 150)();

  TextColumn get telephone => text().nullable()();

  TextColumn get adresse => text().nullable()();

  RealColumn get detteTotale => real().withDefault(const Constant(0))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  /// Indique si la TVA s'applique aux ventes à ce client (1 = oui, 0 = exonéré).
  IntColumn get tvaApplicable => integer().withDefault(const Constant(1))();

  /// Délai de paiement accordé, en jours (ex: 30, 60). NULL = comptant.
  IntColumn get delaiPaiementJours => integer().nullable()();

  /// Conditions textuelles, ex: '30 jours fin de mois'.
  TextColumn get conditionsReglement => text().nullable()();

  /// Numéro d'Identification Fiscale du client (entreprise/professionnel).
  /// Affiché sur les factures PDF quand renseigné.
  TextColumn get nif => text().nullable()();
}
