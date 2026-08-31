import '../../domain/entities/user.dart';

/// Centralise les règles de permissions admin/employé. Toute
/// vérification de droit dans l'application doit passer par cette
/// classe plutôt que de comparer `user.role` directement, pour garder
/// une seule source de vérité si les règles évoluent.
///
/// Périmètre actuel (validé) : un employé n'a accès qu'à un
/// sous-ensemble restreint de modules — Tableau de bord, Articles,
/// Clients, Ventes (Factures), Devis — pour uniquement vendre, sans
/// jamais voir les prix d'achat, les fournisseurs, ni les autres
/// données de gestion (stock, dettes, magasins, paramètres). Il ne
/// modifie que les ventes dont il est l'auteur (`peutModifierDocument`).
/// Le hub "Documents" (Proforma→BC→PL→BL→Retour, chaîne documentaire
/// complète) lui est fermé : aucune de ses tâches n'en dépend, son
/// historique de ventes reste couvert par "Ventes".
///
/// Implémenté en LISTE BLANCHE de préfixes de route plutôt qu'en
/// liste noire : un nouveau module ajouté plus tard sera bloqué pour
/// l'employé par défaut, sauf ajout explicite ici — plus sûr qu'une
/// liste noire qu'on pourrait oublier de mettre à jour.
class Permissions {
  Permissions._();

  /// Préfixes de route accessibles à un employé. Toute route dont le
  /// chemin ne commence par aucun de ces préfixes est réservée admin.
  static const List<String> _routesAutoriseesEmploye = [
    '/dashboard',
    '/articles',
    '/clients',
    '/invoices',
    '/quotes',
    '/factures-v2',
    '/ventes',
    '/about',
  ];

  /// Sous-routes explicitement interdites à l'employé même si elles
  /// commencent par un préfixe autorisé ci-dessus : la création d'un
  /// nouvel article reste une décision admin. L'édition d'un article
  /// existant (/articles/:id/edit) reste accessible mais s'ouvre en
  /// lecture seule pour un employé (géré par l'écran lui-même), pour
  /// lui permettre de consulter le détail sans pouvoir le modifier.
  static const List<String> _routesInterditesEmployeMemesiPrefixeAutorise = [
    '/articles/new',
    '/articles/import',
  ];

  static bool peutAccederRoute(UserEntity? user, String chemin) {
    if (user?.estAdmin ?? false) return true;

    final estSousRouteInterdite = _routesInterditesEmployeMemesiPrefixeAutorise
        .any((p) => chemin.startsWith(p));
    if (estSousRouteInterdite) return false;

    return _routesAutoriseesEmploye.any((prefixe) => chemin.startsWith(prefixe));
  }

  static bool peutGererParametresEntreprise(UserEntity? user) =>
      user?.estAdmin ?? false;

  static bool peutModifierPrixArticle(UserEntity? user) =>
      user?.estAdmin ?? false;

  static bool peutSupprimerArticle(UserEntity? user) =>
      user?.estAdmin ?? false;

  static bool peutGererUtilisateurs(UserEntity? user) =>
      user?.estAdmin ?? false;

  /// Création/modification/suppression d'un article : décision de
  /// gestion du catalogue, réservée admin. Un employé ne fait que
  /// consulter le catalogue existant pour vendre.
  static bool peutGererCatalogueArticles(UserEntity? user) =>
      user?.estAdmin ?? false;

  /// Un employé ne doit jamais voir le prix d'achat d'un article, ni
  /// aucune donnée qui permettrait de le déduire (ex: bénéfice/marge).
  static bool peutVoirPrixAchat(UserEntity? user) => user?.estAdmin ?? false;

  static bool peutVoirBenefice(UserEntity? user) => user?.estAdmin ?? false;

  /// Un employé ne doit pas connaître les fournisseurs du commerce.
  static bool peutVoirFournisseurs(UserEntity? user) => user?.estAdmin ?? false;

  /// Créer / modifier / supprimer un achat fournisseur : réservé admin,
  /// un employé n'a jamais accès au module Achats.
  static bool peutGererAchats(UserEntity? user) => user?.estAdmin ?? false;

  static bool peutImporterDonnees(UserEntity? user) => user?.estAdmin ?? false;

  static bool peutExporterDonnees(UserEntity? user) => user?.estAdmin ?? false;

  static bool peutRestaurerSauvegarde(UserEntity? user) =>
      user?.estAdmin ?? false;

  static bool peutAccederDiagnostic(UserEntity? user) => user?.estAdmin ?? false;

  /// Un employé ne peut modifier une vente que s'il en est l'auteur ;
  /// un admin peut toujours modifier n'importe quelle vente.
  static bool peutModifierDocument(UserEntity? user, int? createdById) {
    if (user?.estAdmin ?? false) return true;
    if (user == null) return false;
    return createdById != null && createdById == user.id;
  }
}
