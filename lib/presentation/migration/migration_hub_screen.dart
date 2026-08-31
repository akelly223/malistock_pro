import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/access_denied_view.dart';

class MigrationHubScreen extends ConsumerWidget {
  const MigrationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutImporterDonnees(utilisateur)) {
      return const AccessDeniedView(titre: 'Migration des données');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration des données'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête explicatif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Importez vos données existantes',
                              style: AppTextStyles.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                            'MaliStock Pro accepte les fichiers TXT, CSV et Excel (.xlsx) '
                            'exportés depuis Sage, Excel ou tout autre logiciel. '
                            'La détection des colonnes est automatique.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Text('Importation', style: AppTextStyles.h3),
              const SizedBox(height: 14),

              // Cartes d'import
              _ImportCard(
                icon: Icons.inventory_2_rounded,
                couleur: AppColors.primary,
                titre: 'Importer les articles',
                sousTitre:
                    'Code, désignation, prix achat/vente, stock, code-barres…',
                route: '/migration/articles',
              ),
              const SizedBox(height: 10),
              _ImportCard(
                icon: Icons.people_alt_rounded,
                couleur: AppColors.secondary,
                titre: 'Importer les clients',
                sousTitre:
                    'Nom, téléphone, adresse, NIF, e-mail…',
                route: '/migration/clients',
              ),
              const SizedBox(height: 10),
              _ImportCard(
                icon: Icons.storefront_rounded,
                couleur: const Color(0xFF5B63B7),
                titre: 'Importer les fournisseurs',
                sousTitre: 'Nom, téléphone, adresse, NIF…',
                route: '/migration/fournisseurs',
              ),
              const SizedBox(height: 10),
              _ImportCard(
                icon: Icons.warehouse_rounded,
                couleur: const Color(0xFF7B5EA7),
                titre: 'Importer les stocks',
                sousTitre:
                    'Mettre à jour les quantités par article (ajouter ou remplacer).',
                route: '/migration/stock',
              ),

              const SizedBox(height: 28),
              Text('Exportation', style: AppTextStyles.h3),
              const SizedBox(height: 14),

              _ImportCard(
                icon: Icons.download_rounded,
                couleur: AppColors.success,
                titre: 'Exporter les données MaliStock Pro',
                sousTitre:
                    'Sauvegarde complète de votre base de données (.zip)',
                route: '/settings',
                badge: 'Sauvegarde',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final String titre;
  final String sousTitre;
  final String route;
  final bool disabled;
  final String? badge;

  const _ImportCard({
    required this.icon,
    required this.couleur,
    required this.titre,
    required this.sousTitre,
    required this.route,
    this.disabled = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : () => context.push(route),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: couleur, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(titre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(badge!,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          if (disabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Bientôt',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(sousTitre,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
