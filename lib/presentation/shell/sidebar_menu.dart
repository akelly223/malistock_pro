import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/providers/session_provider.dart';
import '../../core/constants/app_identity.dart';
import '../../core/permissions/permissions.dart';
import '../../domain/entities/user.dart';

// ── Configuration ─────────────────────────────────────────────────────────────

class _Entry {
  final String label;
  final IconData icon;
  final String route;
  // Routes filles qui déclenchent le surlignage de cet item dans le sidebar.
  final List<String> subRoutes;

  const _Entry(this.label, this.icon, this.route,
      [this.subRoutes = const []]);

  bool isActive(String current) {
    if (current.startsWith(route)) return true;
    return subRoutes.any((r) => current.startsWith(r));
  }
}

const _entries = <_Entry>[
  _Entry('Tableau de bord', Icons.dashboard_rounded, '/dashboard'),
  _Entry('Ventes', Icons.point_of_sale_rounded, '/factures-v2',
      ['/invoices', '/quotes', '/proformas']),
  _Entry('Achats', Icons.shopping_cart_rounded, '/purchases'),
  _Entry('Articles', Icons.inventory_2_rounded, '/articles'),
  _Entry('Clients', Icons.people_alt_rounded, '/clients'),
  _Entry('Dettes', Icons.account_balance_wallet_rounded, '/debts'),
  _Entry('Historique paiements', Icons.receipt_long_rounded, '/receipts'),
  _Entry('Fournisseurs', Icons.storefront_rounded, '/suppliers'),
  _Entry('Stock', Icons.warehouse_rounded, '/stock-hub',
      ['/stock', '/alerts', '/stores', '/inventory']),
  _Entry('Documents', Icons.folder_copy_rounded, '/documents',
      ['/bons-commande', '/preparations-livraison', '/bons-livraison', '/bons-retour', '/avoirs']),
  _Entry('Utilisateurs', Icons.manage_accounts_rounded, '/users'),
  _Entry('Paramètres', Icons.settings_rounded, '/settings'),
];

// ── Widget ────────────────────────────────────────────────────────────────────

class SidebarMenu extends ConsumerWidget {
  final String currentRoute;
  const SidebarMenu({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);

    return Container(
      width: 220,
      color: AppColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _buildItems(context, user),
            ),
          ),
          const Divider(color: Color(0xFF274A40), height: 1),
          _buildFooter(context, ref, user),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MaliStock Pro',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('v${AppIdentity.version}',
                      style:
                          const TextStyle(color: Color(0xFF4D8C6F), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _buildItems(BuildContext context, UserEntity? user) {
    final result = <Widget>[];
    for (final entry in _entries) {
      if (!Permissions.peutAccederRoute(user, entry.route)) continue;
      final actif = entry.isActive(currentRoute);
      result.add(Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: _NavButton(
          label: entry.label,
          icon: entry.icon,
          actif: actif,
          onTap: () => context.go(entry.route),
        ),
      ));
    }
    return result;
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, UserEntity? user) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.secondary,
              radius: 15,
              child: Text(
                (user?.nom.isNotEmpty == true ? user!.nom[0] : '?')
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nom ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user?.estAdmin == true ? 'Administrateur' : 'Employé',
                    style: const TextStyle(
                        color: AppColors.sidebarText, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: AppColors.sidebarText, size: 17),
              tooltip: 'Déconnexion',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                ref.read(sessionProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
      );
}

// ── Bouton générique ──────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool actif;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: actif ? AppColors.sidebarItemActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 17,
                  color: actif ? Colors.white : AppColors.sidebarText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: actif ? Colors.white : AppColors.sidebarText,
                    fontSize: 12.5,
                    fontWeight:
                        actif ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
