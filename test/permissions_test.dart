import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/permissions/permissions.dart';
import 'package:malistock_pro/domain/entities/user.dart';

/// Vérifie la matrice complète de permissions admin/employé demandée :
/// chaque ✓/❌ de la spécification est un cas de test précis, plutôt
/// qu'un contrôle manuel non reproductible.
void main() {
  final admin = UserEntity(
    id: 1,
    nom: 'Admin',
    login: 'admin',
    role: 'admin',
    actif: true,
    dateCreation: DateTime(2026),
  );

  final employe = UserEntity(
    id: 2,
    nom: 'Employé',
    login: 'employe',
    role: 'employe',
    actif: true,
    dateCreation: DateTime(2026),
  );

  group('Administrateur — tous les droits', () {
    test('gère les utilisateurs', () {
      expect(Permissions.peutGererUtilisateurs(admin), isTrue);
    });

    test('voit les prix d\'achat, le bénéfice et la marge', () {
      expect(Permissions.peutVoirPrixAchat(admin), isTrue);
      expect(Permissions.peutVoirBenefice(admin), isTrue);
    });

    test('gère les achats (créer/modifier/supprimer)', () {
      expect(Permissions.peutGererAchats(admin), isTrue);
    });

    test('gère les fournisseurs', () {
      expect(Permissions.peutVoirFournisseurs(admin), isTrue);
    });

    test('gère le catalogue articles, modifie le prix, supprime un article',
        () {
      expect(Permissions.peutGererCatalogueArticles(admin), isTrue);
      expect(Permissions.peutModifierPrixArticle(admin), isTrue);
      expect(Permissions.peutSupprimerArticle(admin), isTrue);
    });

    test('modifie les paramètres de l\'entreprise', () {
      expect(Permissions.peutGererParametresEntreprise(admin), isTrue);
    });

    test('importe et exporte des données, restaure une sauvegarde', () {
      expect(Permissions.peutImporterDonnees(admin), isTrue);
      expect(Permissions.peutExporterDonnees(admin), isTrue);
      expect(Permissions.peutRestaurerSauvegarde(admin), isTrue);
    });

    test('accède au diagnostic SQLite', () {
      expect(Permissions.peutAccederDiagnostic(admin), isTrue);
    });

    test('accède à tous les modules, y compris ceux réservés', () {
      for (final route in [
        '/dashboard', '/articles', '/clients', '/factures-v2', '/ventes',
        '/quotes', '/invoices', '/about',
        '/purchases', '/suppliers', '/users', '/settings', '/migration',
        '/diagnostic', '/documents', '/debts', '/receipts', '/stock',
      ]) {
        expect(Permissions.peutAccederRoute(admin, route), isTrue,
            reason: 'admin devrait accéder à $route');
      }
    });

    test('modifie n\'importe quelle vente, même créée par un autre', () {
      expect(Permissions.peutModifierDocument(admin, employe.id), isTrue);
      expect(Permissions.peutModifierDocument(admin, null), isTrue);
    });
  });

  group('Employé — vendeur uniquement', () {
    test('ne peut pas créer/modifier/supprimer un utilisateur', () {
      expect(Permissions.peutGererUtilisateurs(employe), isFalse);
    });

    test('n\'accède pas aux paramètres', () {
      expect(Permissions.peutGererParametresEntreprise(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/settings'), isFalse);
    });

    test('ne peut pas effectuer, modifier ou supprimer un achat', () {
      expect(Permissions.peutGererAchats(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/purchases'), isFalse);
    });

    test('ne peut pas créer/modifier/supprimer un fournisseur', () {
      expect(Permissions.peutVoirFournisseurs(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/suppliers'), isFalse);
    });

    test('ne voit jamais le prix d\'achat, la marge ni le bénéfice', () {
      expect(Permissions.peutVoirPrixAchat(employe), isFalse);
      expect(Permissions.peutVoirBenefice(employe), isFalse);
    });

    test('ne peut pas importer de données ni restaurer une sauvegarde', () {
      expect(Permissions.peutImporterDonnees(employe), isFalse);
      expect(Permissions.peutRestaurerSauvegarde(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/migration'), isFalse);
    });

    test('n\'accède pas au diagnostic SQLite', () {
      expect(Permissions.peutAccederDiagnostic(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/diagnostic'), isFalse);
    });

    test('ne modifie pas le catalogue ni les prix articles', () {
      expect(Permissions.peutGererCatalogueArticles(employe), isFalse);
      expect(Permissions.peutModifierPrixArticle(employe), isFalse);
      expect(Permissions.peutSupprimerArticle(employe), isFalse);
      expect(Permissions.peutAccederRoute(employe, '/articles/new'), isFalse);
      expect(
          Permissions.peutAccederRoute(employe, '/articles/import'), isFalse);
    });

    test('n\'accède pas à la chaîne documentaire ni aux dettes/reçus', () {
      for (final route in [
        '/documents', '/proformas', '/bons-commande',
        '/preparations-livraison', '/bons-livraison', '/bons-retour',
        '/debts', '/receipts', '/stock', '/alerts', '/stores',
      ]) {
        expect(Permissions.peutAccederRoute(employe, route), isFalse,
            reason: 'employé ne devrait pas accéder à $route');
      }
    });

    test('accède au tableau de bord, aux ventes, articles, clients, devis',
        () {
      for (final route in [
        '/dashboard', '/articles', '/clients', '/factures-v2', '/ventes',
        '/quotes', '/invoices', '/about',
      ]) {
        expect(Permissions.peutAccederRoute(employe, route), isTrue,
            reason: 'employé devrait accéder à $route');
      }
    });

    test('modifie une vente qu\'il a créée, mais pas celle d\'un autre', () {
      expect(Permissions.peutModifierDocument(employe, employe.id), isTrue);
      expect(Permissions.peutModifierDocument(employe, admin.id), isFalse);
      expect(Permissions.peutModifierDocument(employe, null), isFalse);
    });
  });
}
