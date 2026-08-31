import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/repository_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/backup_service.dart';
import '../settings/providers/auto_backup_provider.dart';

/// Widget invisible qui déclenche, une seule fois par session, une
/// vérification de sauvegarde automatique quotidienne. Si aucune
/// sauvegarde n'a déjà été faite aujourd'hui (manuelle ou
/// automatique), en crée une silencieusement en arrière-plan.
///
/// Ne notifie l'utilisateur qu'en cas d'ÉCHEC — un succès silencieux
/// évite de polluer l'expérience à chaque lancement, mais un échec
/// doit être visible : un commerçant qui croit ses données protégées
/// alors que la sauvegarde automatique échoue silencieusement depuis
/// des semaines serait pire que l'absence de cette fonctionnalité.
class AutoBackupTrigger extends ConsumerStatefulWidget {
  const AutoBackupTrigger({super.key});

  @override
  ConsumerState<AutoBackupTrigger> createState() => _AutoBackupTriggerState();
}

class _AutoBackupTriggerState extends ConsumerState<AutoBackupTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifierEtSauvegarder());
  }

  Future<void> _verifierEtSauvegarder() async {
    final dejaTentee = ref.read(autoBackupAttemptedProvider);
    if (dejaTentee) return;
    ref.read(autoBackupAttemptedProvider.notifier).state = true;

    final db = ref.read(databaseProvider);
    final resultat = await BackupService.sauvegarderAutomatiquementSiNecessaire(db);

    if (!mounted || resultat == null) return;

    if (!resultat.succes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Sauvegarde automatique impossible. Pensez à sauvegarder manuellement depuis Paramètres.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
