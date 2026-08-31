import 'import_field.dart';

/// Types d'entités importables.
enum ImportEntityType { articles, clients, fournisseurs, stock }

/// Configuration d'un assistant d'import pour un type d'entité donné.
class ImportConfig {
  final ImportEntityType entityType;
  final String displayName;
  final String icon;
  final List<ImportField> availableFields;
  final List<ImportField> requiredFields;

  const ImportConfig({
    required this.entityType,
    required this.displayName,
    required this.icon,
    required this.availableFields,
    required this.requiredFields,
  });

  static const articles = ImportConfig(
    entityType: ImportEntityType.articles,
    displayName: 'Articles',
    icon: '📚',
    availableFields: [
      ImportField.codeArticle,
      ImportField.famille,
      ImportField.designation,
      ImportField.prixAchat,
      ImportField.prixVente,
      ImportField.stockInitial,
      ImportField.stockMinimum,
      ImportField.codeBarres,
    ],
    requiredFields: [
      ImportField.codeArticle,
      ImportField.designation,
      ImportField.prixVente,
    ],
  );

  static const clients = ImportConfig(
    entityType: ImportEntityType.clients,
    displayName: 'Clients',
    icon: '👥',
    availableFields: [
      ImportField.nom,
      ImportField.telephone,
      ImportField.adresse,
      ImportField.nif,
      ImportField.email,
      ImportField.limiteCredit,
    ],
    requiredFields: [ImportField.nom],
  );

  static const fournisseurs = ImportConfig(
    entityType: ImportEntityType.fournisseurs,
    displayName: 'Fournisseurs',
    icon: '🏢',
    availableFields: [
      ImportField.nom,
      ImportField.telephone,
      ImportField.adresse,
      ImportField.nif,
      ImportField.email,
    ],
    requiredFields: [ImportField.nom],
  );

  static const stock = ImportConfig(
    entityType: ImportEntityType.stock,
    displayName: 'Stocks',
    icon: '📦',
    availableFields: [
      ImportField.codeArticle,
      ImportField.stockInitial,
    ],
    requiredFields: [ImportField.codeArticle],
  );
}
