import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_provider.dart';
import '../providers/active_container_provider.dart';
import '../../core/permissions/permissions.dart';
import '../../core/constants/db_constants.dart';
import '../../presentation/shell/main_shell.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/container/accueil_screen.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/articles/articles_list_screen.dart';
import '../../presentation/articles/article_form_screen.dart';
import '../../presentation/clients/clients_list_screen.dart';
import '../../presentation/clients/client_form_screen.dart';
import '../../presentation/clients/client_detail_screen.dart';
import '../../presentation/suppliers/suppliers_list_screen.dart';
import '../../presentation/suppliers/supplier_detail_screen.dart';
import '../../presentation/purchases/purchases_list_screen.dart';
import '../../presentation/purchases/purchase_form_screen.dart';
import '../../presentation/purchases/purchase_detail_screen.dart';
import '../../presentation/quotes/quotes_list_screen.dart';
import '../../presentation/quotes/quote_form_screen.dart';
import '../../presentation/invoices/invoices_list_screen.dart';
import '../../presentation/invoices/invoice_form_screen.dart';
import '../../presentation/invoices/invoice_detail_screen.dart';
import '../../presentation/debts/debts_list_screen.dart';
import '../../presentation/receipts/payment_receipts_list_screen.dart';
import '../../presentation/receipts/payment_receipt_detail_screen.dart';
import '../../presentation/stores/stores_list_screen.dart';
import '../../presentation/stock/stock_movements_screen.dart';
import '../../presentation/alerts/stock_alerts_screen.dart';
import '../../presentation/users/users_list_screen.dart';
import '../../presentation/articles/article_import_screen.dart';
import '../../presentation/about/about_screen.dart';
import '../../presentation/diagnostic/diagnostic_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/commercial_documents/documents_hub_screen.dart';
import '../../presentation/commercial_documents/documents_list_screen.dart';
import '../../presentation/commercial_documents/document_form_screen.dart';
import '../../presentation/commercial_documents/document_detail_screen.dart';
import '../../presentation/commercial_documents/pick_list_screen.dart';
import '../../presentation/ventes/ventes_hub_screen.dart';
import '../../presentation/migration/migration_hub_screen.dart';
import '../../presentation/migration/import_wizard_screen.dart';
import '../../presentation/inventory/inventory_list_screen.dart';
import '../../presentation/inventory/inventory_detail_screen.dart';
import '../../core/import/import_config.dart';
import '../../domain/entities/document_type.dart';

/// Notifie GoRouter lorsque l'état de connexion change, pour
/// déclencher le redirect automatiquement (sinon GoRouter ne
/// réévalue pas `redirect` lors d'un changement de provider Riverpod).
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
    ref.listen(activeContainerProvider, (_, __) => notifyListeners());
  }
}

/// Renseigné juste avant un redirect pour cause de permission refusée,
/// afin que `AccessDeniedTrigger` (dans `main_shell.dart`) puisse
/// afficher un message visible une fois arrivé sur `/dashboard` — sinon
/// le refus est complètement silencieux pour l'utilisateur.
final accessDeniedRouteProvider = StateProvider<String?>((ref) => null);

/// Clé du Navigator racine de GoRouter, exposée pour que
/// `NativeChannelListener` puisse déclencher une navigation/un
/// dialogue depuis un événement natif (réception `WM_COPYDATA`) qui ne
/// dispose d'aucun `BuildContext` de départ.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/accueil',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Aucun dossier .mstk ouvert : seul l'écran d'accueil est
      // accessible. C'est déterminant AVANT la logique de connexion
      // ci-dessous, car /login interroge la base (hasAdminProvider)
      // dès son affichage — elle doit donc déjà pointer sur un
      // conteneur ouvert.
      final conteneurOuvert = ref.read(activeContainerProvider) != null;
      final vaVersAccueil = state.matchedLocation == '/accueil';

      // Tant qu'aucun conteneur n'est ouvert, seul /accueil est
      // atteignable : on s'arrête ici pour ne jamais retomber dans la
      // logique de connexion ci-dessous (sinon boucle de redirection
      // /accueil <-> /login, /login exigeant lui aussi une garde).
      if (!conteneurOuvert) return vaVersAccueil ? null : '/accueil';
      if (vaVersAccueil) return '/login';

      final user = ref.read(sessionProvider);
      final isConnecte = user != null;
      final vaVersLogin = state.matchedLocation == '/login';

      if (!isConnecte && !vaVersLogin) return '/login';
      if (isConnecte && vaVersLogin) return '/dashboard';

      // Garde de permission : un employé n'a accès qu'à un
      // sous-ensemble restreint de modules (liste blanche dans
      // Permissions). Vérifié ici au niveau du routeur, pas
      // seulement par le masquage du menu, pour empêcher tout accès
      // direct par URL à un module qui lui est interdit (Achats,
      // Fournisseurs, Magasins, Stock, Dettes, Alertes, Utilisateurs,
      // Paramètres).
      if (isConnecte &&
          !vaVersLogin &&
          !Permissions.peutAccederRoute(user, state.matchedLocation)) {
        ref.read(accessDeniedRouteProvider.notifier).state =
            state.matchedLocation;
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/accueil',
        builder: (context, state) => const AccueilScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // Hubs de navigation
          GoRoute(
            path: '/ventes',
            builder: (_, __) => const VentesHubScreen(),
          ),
          GoRoute(
            path: '/achats',
            builder: (_, __) => const AchatsHubScreen(),
          ),
          GoRoute(
            path: '/stock-hub',
            builder: (_, __) => const StockHubScreen(),
          ),

          // Articles
          GoRoute(
            path: '/articles',
            builder: (context, state) => const ArticlesListScreen(),
          ),
          GoRoute(
            path: '/articles/new',
            builder: (context, state) => const ArticleFormScreen(),
          ),
          GoRoute(
            path: '/articles/import',
            builder: (context, state) => const ArticleImportScreen(),
          ),
          GoRoute(
            path: '/articles/:id/edit',
            builder: (context, state) => ArticleFormScreen(
              articleId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Clients
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsListScreen(),
          ),
          GoRoute(
            path: '/clients/new',
            builder: (context, state) => const ClientFormScreen(),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (context, state) => ClientDetailScreen(
              clientId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/clients/:id/edit',
            builder: (context, state) => ClientFormScreen(
              clientId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Fournisseurs
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersListScreen(),
          ),
          GoRoute(
            path: '/suppliers/:id',
            builder: (context, state) => SupplierDetailScreen(
              supplierId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Achats fournisseurs
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesListScreen(),
          ),
          GoRoute(
            path: '/purchases/new',
            builder: (context, state) => PurchaseFormScreen(
              initialStatut: state.uri.queryParameters['type'] ==
                      DbConstants.purchaseStatutCommande
                  ? DbConstants.purchaseStatutCommande
                  : DbConstants.purchaseStatutRecu,
            ),
          ),
          GoRoute(
            path: '/purchases/:id',
            builder: (context, state) => PurchaseDetailScreen(
              purchaseId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/purchases/:id/edit',
            builder: (context, state) => PurchaseFormScreen(
              purchaseId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Devis
          GoRoute(
            path: '/quotes',
            builder: (context, state) => const QuotesListScreen(),
          ),
          GoRoute(
            path: '/quotes/new',
            builder: (context, state) => const QuoteFormScreen(),
          ),
          GoRoute(
            path: '/quotes/:id/edit',
            builder: (context, state) => QuoteFormScreen(
              quoteId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Factures
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesListScreen(),
          ),
          GoRoute(
            path: '/invoices/new',
            builder: (context, state) => const InvoiceFormScreen(),
          ),
          GoRoute(
            path: '/invoices/:id',
            builder: (context, state) => InvoiceDetailScreen(
              invoiceId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/invoices/:id/edit',
            builder: (context, state) => InvoiceFormScreen(
              invoiceId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Dettes
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsListScreen(),
          ),
          GoRoute(
            path: '/receipts',
            builder: (context, state) => const PaymentReceiptsListScreen(),
          ),
          GoRoute(
            path: '/receipts/:source/:paymentId',
            builder: (context, state) => PaymentReceiptDetailScreen(
              source: state.pathParameters['source']!,
              paymentId: int.parse(state.pathParameters['paymentId']!),
            ),
          ),

          // Magasins
          GoRoute(
            path: '/stores',
            builder: (context, state) => const StoresListScreen(),
          ),

          // Stock
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockMovementsScreen(),
          ),

          // Alertes de stock
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const StockAlertsScreen(),
          ),

          // Inventaire
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryListScreen(),
          ),
          GoRoute(
            path: '/inventory/:id',
            builder: (context, state) => InventoryDetailScreen(
              inventoryId: int.parse(state.pathParameters['id']!),
            ),
          ),


          // Utilisateurs (réservé admin)
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersListScreen(),
          ),

          // Paramètres
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          // Migration des données
          GoRoute(
            path: '/migration',
            builder: (_, __) => const MigrationHubScreen(),
          ),
          GoRoute(
            path: '/migration/articles',
            builder: (_, __) => const ImportWizardScreen(
                entityType: ImportEntityType.articles),
          ),
          GoRoute(
            path: '/migration/clients',
            builder: (_, __) => const ImportWizardScreen(
                entityType: ImportEntityType.clients),
          ),
          GoRoute(
            path: '/migration/fournisseurs',
            builder: (_, __) => const ImportWizardScreen(
                entityType: ImportEntityType.fournisseurs),
          ),
          GoRoute(
            path: '/migration/stock',
            builder: (_, __) => const ImportWizardScreen(
                entityType: ImportEntityType.stock),
          ),

          // À propos (accessible à tous les rôles)
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),

          // Diagnostic SQLite (admin uniquement, temporaire)
          GoRoute(
            path: '/diagnostic',
            builder: (context, state) => const DiagnosticScreen(),
          ),

          // Hub Documents (cartes de navigation vers chaque type de pièce)
          GoRoute(
            path: '/documents',
            builder: (_, __) => const DocumentsHubScreen(),
          ),

          // ── Documents commerciaux ────────────────────────────────────────

          // Proformas
          GoRoute(
            path: '/proformas',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.proforma),
          ),
          GoRoute(
            path: '/proformas/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.proforma,
              routePrefix: '/proformas',
            ),
          ),
          GoRoute(
            path: '/proformas/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/proformas',
            ),
          ),
          GoRoute(
            path: '/proformas/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.proforma,
              routePrefix: '/proformas',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Bons de commande
          GoRoute(
            path: '/bons-commande',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.bonCommande),
          ),
          GoRoute(
            path: '/bons-commande/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.bonCommande,
              routePrefix: '/bons-commande',
            ),
          ),
          GoRoute(
            path: '/bons-commande/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/bons-commande',
            ),
          ),
          GoRoute(
            path: '/bons-commande/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.bonCommande,
              routePrefix: '/bons-commande',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Bons de livraison
          GoRoute(
            path: '/bons-livraison',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.bonLivraison),
          ),
          GoRoute(
            path: '/bons-livraison/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.bonLivraison,
              routePrefix: '/bons-livraison',
            ),
          ),
          GoRoute(
            path: '/bons-livraison/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/bons-livraison',
            ),
          ),
          GoRoute(
            path: '/bons-livraison/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.bonLivraison,
              routePrefix: '/bons-livraison',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Factures V2 (avec TVA)
          GoRoute(
            path: '/factures-v2',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.facture),
          ),
          GoRoute(
            path: '/factures-v2/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.facture,
              routePrefix: '/factures-v2',
            ),
          ),
          GoRoute(
            path: '/factures-v2/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/factures-v2',
            ),
          ),
          GoRoute(
            path: '/factures-v2/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.facture,
              routePrefix: '/factures-v2',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Préparations de livraison (Phase 6 — pick list)
          GoRoute(
            path: '/preparations-livraison',
            builder: (_, __) => const DocumentsListScreen(
                type: DocumentType.preparationLivraison),
          ),
          GoRoute(
            path: '/preparations-livraison/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.preparationLivraison,
              routePrefix: '/preparations-livraison',
            ),
          ),
          GoRoute(
            path: '/preparations-livraison/:id',
            builder: (_, state) => PickListScreen(
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/preparations-livraison/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.preparationLivraison,
              routePrefix: '/preparations-livraison',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Bons de retour (Phase 5)
          GoRoute(
            path: '/bons-retour',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.bonRetour),
          ),
          GoRoute(
            path: '/bons-retour/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.bonRetour,
              routePrefix: '/bons-retour',
            ),
          ),
          GoRoute(
            path: '/bons-retour/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/bons-retour',
            ),
          ),
          GoRoute(
            path: '/bons-retour/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.bonRetour,
              routePrefix: '/bons-retour',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),

          // Avoirs (Phase 5)
          GoRoute(
            path: '/avoirs',
            builder: (_, __) =>
                const DocumentsListScreen(type: DocumentType.avoir),
          ),
          GoRoute(
            path: '/avoirs/new',
            builder: (_, __) => const DocumentFormScreen(
              type: DocumentType.avoir,
              routePrefix: '/avoirs',
            ),
          ),
          GoRoute(
            path: '/avoirs/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: int.parse(state.pathParameters['id']!),
              routePrefix: '/avoirs',
            ),
          ),
          GoRoute(
            path: '/avoirs/:id/edit',
            builder: (_, state) => DocumentFormScreen(
              type: DocumentType.avoir,
              routePrefix: '/avoirs',
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});
