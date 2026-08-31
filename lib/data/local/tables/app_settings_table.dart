import 'package:drift/drift.dart';

/// Table des paramètres de l'entreprise. Conçue pour ne contenir
/// qu'une seule ligne (id fixe = 1), utilisée pour personnaliser les
/// documents imprimés (factures, devis, achats) avec l'identité du
/// commerce : nom, téléphone, adresse, logo.
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nomEntreprise =>
      text().withDefault(const Constant('Ma Boutique'))();

  TextColumn get telephone => text().nullable()();

  TextColumn get adresse => text().nullable()();

  /// Chemin absolu vers le fichier logo sur le disque (PNG/JPG),
  /// copié dans le dossier de données de l'application lors de
  /// l'import pour éviter de dépendre d'un chemin externe fragile.
  TextColumn get logoPath => text().nullable()();

  TextColumn get email => text().nullable()();

  /// Courte phrase d'activité affichée sous le nom du commerce sur
  /// la facture imprimée, ex: "Livres - Formations - Informatique".
  TextColumn get slogan => text().nullable()();

  TextColumn get commentairePiedDePage => text().withDefault(const Constant(
      'Marchandise vendue ni reprise ni échangée.\nMerci pour votre confiance. Revenez bientôt.'))();

  TextColumn get nif => text().nullable()();
  TextColumn get rccm => text().nullable()();
  TextColumn get ifu => text().nullable()();

  BoolColumn get tvaActive =>
      boolean().withDefault(const Constant(false))();

  RealColumn get tauxTva =>
      real().withDefault(const Constant(18.0))();

  TextColumn get devise =>
      text().withDefault(const Constant('FCFA'))();

  TextColumn get signaturePath => text().nullable()();
  TextColumn get cachetPath => text().nullable()();
}
