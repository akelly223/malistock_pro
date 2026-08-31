import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/services/draft_service.dart';
import '../alerts/providers/stock_alerts_provider.dart';

/// Widget invisible qui vérifie, au premier affichage du shell, si des
/// brouillons ont été laissés en cours. Si oui, propose à l'utilisateur
/// de reprendre son travail ou d'ignorer les brouillons.
///
/// Ne s'exécute qu'une seule fois par session (même pattern que
/// [StartupAlertTrigger]).
class StartupDraftChecker extends ConsumerStatefulWidget {
  const StartupDraftChecker({super.key});

  @override
  ConsumerState<StartupDraftChecker> createState() =>
      _StartupDraftCheckerState();
}

class _StartupDraftCheckerState extends ConsumerState<StartupDraftChecker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifier());
  }

  Future<void> _verifier() async {
    final dejaAffiche = ref.read(startupDraftCheckerShownProvider);
    if (dejaAffiche) return;
    ref.read(startupDraftCheckerShownProvider.notifier).state = true;

    final service = ref.read(draftServiceProvider);
    final brouillons = await service.listerBrouillons();
    if (!mounted || brouillons.isEmpty) return;

    _afficherDialog(brouillons);
  }

  void _afficherDialog(List<DraftInfo> brouillons) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final restants = brouillons.toList();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Brouillons retrouvés')),
              ],
            ),
            content: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 500, maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous avez ${restants.length} brouillon(s) '
                      'non enregistré(s). Voulez-vous reprendre '
                      'votre travail ?',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 16),
                    ...restants.map((b) => _BrouillonTile(
                          brouillon: b,
                          onReprendre: () {
                            Navigator.of(ctx).pop();
                            context.push(DraftType.route(b.type));
                          },
                          onIgnorer: () async {
                            final service =
                                ref.read(draftServiceProvider);
                            await service.supprimerBrouillon(b.type);
                            setDialogState(() => restants.remove(b));
                            if (restants.isEmpty && ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          },
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final service = ref.read(draftServiceProvider);
                  await service.supprimerTous();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Ignorer tous'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _BrouillonTile extends StatelessWidget {
  final DraftInfo brouillon;
  final VoidCallback onReprendre;
  final VoidCallback onIgnorer;

  const _BrouillonTile({
    required this.brouillon,
    required this.onReprendre,
    required this.onIgnorer,
  });

  String _ageFormate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return 'il y a ${diff.inDays} jour(s)';
    if (diff.inHours >= 1) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes >= 1) return 'il y a ${diff.inMinutes} min';
    return 'à l\'instant';
  }

  @override
  Widget build(BuildContext context) {
    final nb = brouillon.nbArticles;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DraftType.libelle(brouillon.type),
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  '$nb article(s) — ${_ageFormate(brouillon.dateSauvegarde)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onIgnorer,
            child: const Text('Ignorer'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onReprendre,
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
  }
}
