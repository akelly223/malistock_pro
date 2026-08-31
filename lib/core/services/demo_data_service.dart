import '../../app/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item_input.dart';
import '../constants/db_constants.dart';

/// Crée un jeu de données de démonstration réaliste (articles,
/// clients, fournisseurs, factures) pour qu'un commerçant puisse
/// tester immédiatement l'application sans tout saisir lui-même.
///
/// Conçu pour être appelé une seule fois, juste après la création du
/// compte administrateur au premier lancement — jamais depuis
/// l'installateur Windows, qui ne peut pas écrire dans SQLite de
/// façon fiable (voir notes de déploiement).
class DemoDataService {
  DemoDataService._();

  static Future<void> creerDonneesDemo(WidgetRef ref, {required int userId}) async {
    final storeRepo = ref.read(storeRepositoryProvider);
    final articleRepo = ref.read(articleRepositoryProvider);
    final clientRepo = ref.read(clientRepositoryProvider);
    final supplierRepo = ref.read(supplierRepositoryProvider);
    final invoiceRepo = ref.read(invoiceRepositoryProvider);

    // Magasin principal, nécessaire pour toute vente/stock.
    final storeId = await storeRepo.createStore(
      nom: 'Boutique principale',
      adresse: 'Grand Marché, Bamako',
      estPrincipal: true,
    );

    // Catégories de base.
    final catAlimentaire = await articleRepo.createCategory('Alimentaire');
    final catBoissons = await articleRepo.createCategory('Boissons');

    // Articles avec stock initial.
    final articlesDefinis = [
      ('RIZ-001', 'Riz Gambiaka 25kg', catAlimentaire, 18000.0, 22000.0, 10.0, 30.0),
      ('RIZ-002', 'Riz local 25kg', catAlimentaire, 15000.0, 18500.0, 10.0, 20.0),
      ('SUC-001', 'Sucre cristal 1kg', catAlimentaire, 700.0, 950.0, 20.0, 50.0),
      ('HUI-001', 'Huile végétale 1L', catAlimentaire, 1200.0, 1500.0, 15.0, 25.0),
      ('EAU-001', 'Eau minérale 1.5L', catBoissons, 250.0, 400.0, 30.0, 60.0),
      ('JUS-001', 'Jus de gingembre 1L', catBoissons, 800.0, 1200.0, 10.0, 15.0),
    ];

    final articleIds = <String, int>{};
    for (final (code, nom, catId, prixAchat, prixVente, stockMin, stockInitial)
        in articlesDefinis) {
      final id = await articleRepo.createArticle(
        code: code,
        nom: nom,
        categorieId: catId,
        prixAchat: prixAchat,
        prixVente: prixVente,
        stockMinimum: stockMin,
      );
      await articleRepo.adjustStock(
        articleId: id,
        storeId: storeId,
        delta: stockInitial,
      );
      articleIds[code] = id;
    }

    // Clients de démonstration.
    final clientId1 = await clientRepo.createClient(
      nom: 'Aminata Coulibaly',
      telephone: '76 12 34 56',
      adresse: 'Quartier Hippodrome, Bamako',
    );
    await clientRepo.createClient(
      nom: 'Issa Traoré',
      telephone: '65 98 76 54',
      adresse: 'Sogoniko, Bamako',
    );

    // Fournisseurs de démonstration.
    await supplierRepo.createSupplier(
      nom: 'Grossiste Mali Céréales',
      telephone: '70 11 22 33',
      adresse: 'Zone industrielle, Bamako',
    );
    await supplierRepo.createSupplier(
      nom: 'Import Boissons SARL',
      telephone: '78 44 55 66',
      adresse: 'Banankabougou, Bamako',
    );

    // Quelques factures de démonstration, avec stock déjà ajusté
    // ci-dessus pour qu'elles ne le fassent pas passer en négatif.
    await invoiceRepo.createInvoice(
      clientId: clientId1,
      storeId: storeId,
      userId: userId,
      items: [
        CartItemInput(
          articleId: articleIds['RIZ-001']!,
          articleNom: 'Riz Gambiaka 25kg',
          quantite: 2,
          prixUnitaire: 22000,
        ),
        CartItemInput(
          articleId: articleIds['SUC-001']!,
          articleNom: 'Sucre cristal 1kg',
          quantite: 3,
          prixUnitaire: 950,
        ),
      ],
      montantPayeInitial: 46850,
      modePaiementInitial: DbConstants.paymentEspeces,
    );

    await invoiceRepo.createInvoice(
      storeId: storeId,
      userId: userId,
      items: [
        CartItemInput(
          articleId: articleIds['EAU-001']!,
          articleNom: 'Eau minérale 1.5L',
          quantite: 5,
          prixUnitaire: 400,
        ),
      ],
      montantPayeInitial: 2000,
      modePaiementInitial: DbConstants.paymentOrangeMoney,
    );

    // Facture partiellement payée pour illustrer le module Dettes
    // clients dès le premier lancement.
    await invoiceRepo.createInvoice(
      clientId: clientId1,
      storeId: storeId,
      userId: userId,
      items: [
        CartItemInput(
          articleId: articleIds['HUI-001']!,
          articleNom: 'Huile végétale 1L',
          quantite: 4,
          prixUnitaire: 1500,
        ),
      ],
      montantPayeInitial: 3000,
      modePaiementInitial: DbConstants.paymentEspeces,
    );
  }
}
