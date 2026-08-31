import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../domain/entities/article.dart';
import '../alerts/providers/stock_alerts_provider.dart';

/// Widget invisible (ne rend aucune UI propre) qui déclenche une
/// popup d'alerte de stock au premier affichage du shell pendant la
/// session, si des alertes existent. N'affiche la popup qu'une seule
/// fois par lancement de l'application, pas à chaque navigation.
class StartupAlertTrigger extends ConsumerStatefulWidget {
  const StartupAlertTrigger({super.key});

  @override
  ConsumerState<StartupAlertTrigger> createState() =>
      _StartupAlertTriggerState();
}

class _StartupAlertTriggerState extends ConsumerState<StartupAlertTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifierEtAfficher());
  }

  Future<void> _verifierEtAfficher() async {
    final dejaAffichee = ref.read(startupAlertShownProvider);
    if (dejaAffichee) return;

    final alerts = await ref.read(stockAlertsProvider.future);
    if (!mounted || alerts.isEmpty) return;

    // Marque comme affichée avant d'ouvrir la popup pour éviter tout
    // double-déclenchement si le widget est reconstruit pendant l'attente.
    ref.read(startupAlertShownProvider.notifier).state = true;

    if (!mounted) return;
    _afficherPopup(alerts);
  }

  void _afficherPopup(List<ArticleEntity> alerts) {
    final ruptures = alerts.where((a) => a.estEnRuptureTotale).toList();
    final faibles = alerts.where((a) => a.estEnAlerteFaible).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            const Text('Alertes de stock'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ruptures.isNotEmpty) ...[
                  Text('🚨 Rupture de stock', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  ...ruptures.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Rupture de stock : ${a.nom}',
                            style: AppTextStyles.body),
                      )),
                  const SizedBox(height: 12),
                ],
                if (faibles.isNotEmpty) ...[
                  Text('⚠️ Stock faible', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  ...faibles.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                            'Stock faible : ${a.nom} (${a.stockTotal.toStringAsFixed(0)} restant(s))',
                            style: AppTextStyles.body),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Fermer'),
          ),
          AppButton(
            label: 'Voir les alertes',
            onPressed: () {
              context.pop();
              context.push('/alerts');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
