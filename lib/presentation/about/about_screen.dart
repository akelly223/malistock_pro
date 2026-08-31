import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/constants/app_identity.dart';
import '../../core/permissions/permissions.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    final estAdmin = Permissions.peutGererParametresEntreprise(utilisateur);

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo et titre application
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppIdentity.nomApp,
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                Text(
                  AppIdentity.nomCourt,
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Version ${AppIdentity.version}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Base v${AppIdentity.schemaVersion}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppIdentity.description,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // Fonctionnalités
                _Section(
                  titre: 'Fonctionnalités incluses',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: AppIdentity.fonctionnalites
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Text(f, style: AppTextStyles.body),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 28),

                // Éditeur
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        AppIdentity.editeur,
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppIdentity.paysEditeur,
                        style: AppTextStyles.bodyBold,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppIdentity.descriptionEditeur,
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Coordonnées
                _Section(
                  titre: 'Nous contacter',
                  child: Column(
                    children: [
                      _LigneContact(
                          icon: Icons.phone_outlined,
                          label: 'Téléphone',
                          valeur: AppIdentity.telephone),
                      _LigneContact(
                          icon: Icons.chat_bubble_outline,
                          label: 'WhatsApp',
                          valeur: AppIdentity.whatsapp),
                      _LigneContact(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          valeur: AppIdentity.email),
                      _LigneContact(
                          icon: Icons.facebook,
                          label: 'Facebook',
                          valeur: AppIdentity.facebook),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Licence
                _Section(
                  titre: 'Contrat de licence',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Ce logiciel est fourni sous licence commerciale propriétaire. '
                      'Il est accordé à l\'entreprise cliente pour un usage interne exclusif. '
                      'Toute reproduction, redistribution, revente ou modification du logiciel '
                      'sans autorisation écrite de ${AppIdentity.editeur} est strictement interdite. '
                      'L\'accès au code source n\'est pas accordé dans le cadre de cette licence.',
                      style: AppTextStyles.body,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                if (estAdmin) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: const Text('Diagnostic SQLite (admin)'),
                    onPressed: () => context.push('/diagnostic'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  '© 2026 ${AppIdentity.editeur}. Tous droits réservés.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final Widget child;

  const _Section({required this.titre, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: AppTextStyles.h3),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _LigneContact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valeur;

  const _LigneContact({
    required this.icon,
    required this.label,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(valeur, style: AppTextStyles.bodyBold),
            ],
          ),
        ],
      ),
    );
  }
}
