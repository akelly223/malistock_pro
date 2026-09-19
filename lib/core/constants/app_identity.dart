/// Identité de l'éditeur du logiciel, centralisée ici pour éviter
/// de la dupliquer dans chaque écran et chaque PDF. Toute mise à
/// jour (numéro de version, coordonnées) se fait uniquement ici.
///
/// APPLICATION : MaliStock Pro
/// ÉDITEUR     : MALI_CODE CENTER
///
/// NE PAS modifier les valeurs ici manuellement — ce fichier est la
/// source de vérité unique. Toute correction ici se propage
/// automatiquement dans l'écran À propos, l'écran de connexion,
/// les PDF factures/achats, l'écran Paramètres et l'installateur.
class AppIdentity {
  AppIdentity._();

  static const String nomApp = 'MaliStock Pro';
  static const String nomCourt = 'MaliStock Pro';
  static const String version = '3.5.0';
  static const int schemaVersion = 19;
  static const String description =
      'Solution de gestion commerciale conçue pour les commerçants, '
      'libraires, grossistes et détaillants du Mali et d\'Afrique.';

  static const String editeur = 'MALI_CODE CENTER';
  static const String sloganEditeur =
      'Solutions numériques pour les entreprises africaines';
  static const String descriptionEditeur =
      'MALI_CODE CENTER accompagne les entreprises dans leur '
      'transformation numérique grâce à des solutions simples, fiables '
      'et adaptées aux réalités locales.';
  static const String paysEditeur = '🇲🇱 Développé avec fierté au Mali';

  static const String telephone = '+223 75 96 51 85';
  static const String whatsapp = '+223 75 96 51 85';
  static const String email = 'mlcode223@gmail.com';
  static const String facebook = 'facebook.com/mlcode223';

  /// Mention discrète affichée en bas des PDF (factures et achats).
  static const String mentionPdf =
      'Logiciel développé par $editeur · $sloganEditeur';

  static const List<String> fonctionnalites = [
    'Gestion des articles et catégories',
    'Gestion du stock multi-magasin',
    'Gestion des ventes (factures)',
    'Gestion des achats fournisseurs',
    'Gestion des clients et fournisseurs',
    'Génération de factures PDF',
    'Alertes de stock automatiques',
    'Statistiques et tableau de bord',
    'Sauvegarde et restauration des données',
  ];
}
