import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/licence_provider.dart';
import '../../app/theme/app_colors.dart';
import '../../core/licence/licence_service.dart';
import '../../core/licence/licence_write_guard.dart';

/// Bandeau en haut du contenu : rappel dans les derniers jours d'essai,
/// puis rappel permanent de la lecture seule une fois l'essai terminé.
/// Invisible le reste du temps (essai confortable ou licence activée).
class LicenceBanner extends ConsumerWidget {
  const LicenceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(licenceProvider);
    if (!etat.lectureSeule && !etat.afficherRappel) {
      return const SizedBox.shrink();
    }

    final jours = etat.joursRestants;
    final (Color fond, Color texte, String message) = switch (etat.statut) {
      StatutLicence.horlogeIncoherente => (
          AppColors.danger,
          Colors.white,
          'Date de l\'ordinateur incorrecte — lecture seule. Corrigez la date '
              'de Windows puis relancez le logiciel.',
        ),
      StatutLicence.expire => (
          AppColors.danger,
          Colors.white,
          'Période d\'essai terminée — vos données restent consultables, '
              'mais aucune nouvelle opération ne peut être enregistrée.',
        ),
      _ => (
          AppColors.warningLight,
          AppColors.textPrimary,
          'Il vous reste $jours jour${jours > 1 ? 's' : ''} d\'essai gratuit.',
        ),
    };

    return Material(
      color: fond,
      child: Padding(
        // Marge droite : laisse la place à la cloche et au menu Fichier
        // qui flottent en haut à droite (voir MainShell).
        padding: const EdgeInsets.fromLTRB(20, 8, 140, 8),
        child: Row(
          children: [
            Icon(
              etat.lectureSeule ? Icons.lock_rounded : Icons.hourglass_bottom_rounded,
              color: texte,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: texte))),
            const SizedBox(width: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: texte,
                side: BorderSide(color: texte.withValues(alpha: 0.6)),
              ),
              onPressed: () => context.push('/licence'),
              child: const Text('Activer ma licence'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget invisible : quand une écriture est refusée par
/// [LicenceWriteGuard], explique pourquoi dans une boîte de dialogue
/// (quelle que soit la façon dont l'écran d'origine gère l'erreur).
class LicenceBlockedTrigger extends StatefulWidget {
  const LicenceBlockedTrigger({super.key});

  @override
  State<LicenceBlockedTrigger> createState() => _LicenceBlockedTriggerState();
}

class _LicenceBlockedTriggerState extends State<LicenceBlockedTrigger> {
  bool _dialogueOuvert = false;

  @override
  void initState() {
    super.initState();
    LicenceWriteGuard.tentativesBloquees.addListener(_surBlocage);
  }

  @override
  void dispose() {
    LicenceWriteGuard.tentativesBloquees.removeListener(_surBlocage);
    super.dispose();
  }

  Future<void> _surBlocage() async {
    // Une même action peut déclencher plusieurs écritures refusées :
    // un seul dialogue à la fois.
    if (_dialogueOuvert || !mounted) return;
    _dialogueOuvert = true;
    final allerLicence = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_rounded, color: AppColors.danger, size: 36),
        title: const Text('Période d\'essai terminée'),
        content: const Text(
          'Cette opération n\'a pas été enregistrée.\n\n'
          'Vos données restent consultables (voir, imprimer, exporter, '
          'sauvegarder). Pour enregistrer de nouvelles ventes, achats ou '
          'mouvements de stock, activez votre licence à vie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activer ma licence'),
          ),
        ],
      ),
    );
    _dialogueOuvert = false;
    if (allerLicence == true && mounted) context.push('/licence');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
