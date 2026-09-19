import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers/launch_file_provider.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/constants/app_identity.dart';
import '../../core/container/recent_files_service.dart';
import '../../core/services/mstk_migration_service.dart';
import '../../core/widgets/app_button.dart';
import 'container_actions.dart';
import 'widgets/mot_de_passe_dialog.dart';

/// Écran affiché tant qu'aucun dossier `.mstk` n'est ouvert : créer un
/// nouveau dossier, en ouvrir un existant, ou reprendre un fichier
/// récent.
class AccueilScreen extends ConsumerStatefulWidget {
  const AccueilScreen({super.key});

  @override
  ConsumerState<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends ConsumerState<AccueilScreen> {
  bool _isBusy = false;
  late Future<List<String>> _recents;
  late Future<String?> _dossierLegacy;

  @override
  void initState() {
    super.initState();
    _recents = RecentFilesService.lister();
    _dossierLegacy = MstkMigrationService.detecterDossierExistant();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ouvrirFichierDeLancementSiPresent());
  }

  /// Ouvre automatiquement le fichier `.mstk` reçu en argument au
  /// lancement (double-clic depuis l'Explorateur — voir `main.dart` et
  /// `launchFileProvider`), une seule fois au premier affichage.
  Future<void> _ouvrirFichierDeLancementSiPresent() async {
    final chemin = ref.read(launchFileProvider);
    if (chemin == null || !mounted) return;
    await _executer(() =>
        ContainerActions.ouvrir(context, ref, cheminPredefini: chemin));
  }

  Future<void> _executer(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _recents = RecentFilesService.lister();
        });
      }
    }
  }

  Future<void> _convertirDossierExistant(String dossierSource) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convertir vos données existantes'),
        content: const Text(
          'Toutes vos données actuelles (articles, clients, factures, '
          'fournisseurs...) vont être copiées telles quelles dans un '
          'nouveau fichier .mstk — rien n\'est perdu, et votre ancien '
          'dossier reste intact et inchangé.\n\n'
          'À l\'étape suivante, choisissez simplement où enregistrer ce '
          'nouveau fichier.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          AppButton(
              label: 'Continuer',
              onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer vos données converties sous',
      fileName: 'MonEntreprise.mstk',
      allowedExtensions: ['mstk'],
    );
    if (chemin == null || !mounted) return;
    final cheminFinal =
        chemin.toLowerCase().endsWith('.mstk') ? chemin : '$chemin.mstk';

    final motDePasse = await demanderMotDePasse(
      context,
      creation: true,
      titre: 'Protéger vos données converties par un mot de passe ?',
    );
    if (motDePasse == null || !mounted) return;

    await _executer(() async {
      try {
        final ignores = await MstkMigrationService.migrer(
          dossierSource: dossierSource,
          fichierDestination: File(cheminFinal),
          motDePasse: motDePasse == motDePasseAucun ? null : motDePasse,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Conversion réussie : $cheminFinal. Votre ancien dossier '
              'n\'a pas été modifié.'),
          duration: const Duration(seconds: 6),
        ));
        if (ignores.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Certains fichiers n\'ont pas pu être copiés'),
              content: Text(
                '${ignores.length} fichier(s) n\'ont pas pu être lus depuis '
                'leur dossier cloud (iCloud Drive, OneDrive...) et sont '
                'absents du nouveau fichier .mstk — souvent des fichiers '
                'non essentiels (corbeille, fichiers non téléchargés sur ce '
                'poste). Vos données (articles, clients, factures...) ont '
                'bien été converties.\n\n${ignores.join('\n')}',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Compris')),
              ],
            ),
          );
          if (!mounted) return;
        }
        await ContainerActions.ouvrir(context, ref,
            cheminPredefini: cheminFinal);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur : $e')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text('MaliStock Pro', style: AppTextStyles.h1, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Créez un nouveau dossier ou ouvrez un dossier existant '
                    'pour commencer.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Nouveau dossier',
                    icon: Icons.add_circle_outline_rounded,
                    isLoading: _isBusy,
                    onPressed: () =>
                        _executer(() => ContainerActions.nouveau(context, ref)),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Ouvrir un dossier',
                    icon: Icons.folder_open_rounded,
                    isOutlined: true,
                    isLoading: _isBusy,
                    onPressed: () =>
                        _executer(() => ContainerActions.ouvrir(context, ref)),
                  ),
                  FutureBuilder<String?>(
                    future: _dossierLegacy,
                    builder: (context, snapshot) {
                      final dossier = snapshot.data;
                      if (dossier == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Un dossier de données existant (ancien '
                                'format) a été trouvé sur cet ordinateur.',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'Convertir vers le nouveau format',
                                icon: Icons.sync_alt_rounded,
                                isOutlined: true,
                                isLoading: _isBusy,
                                onPressed: () =>
                                    _convertirDossierExistant(dossier),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FutureBuilder<List<String>>(
                    future: _recents,
                    builder: (context, snapshot) {
                      final chemins = snapshot.data ?? const [];
                      if (chemins.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dossiers récents', style: AppTextStyles.bodyBold),
                          const SizedBox(height: 10),
                          ...chemins.map((chemin) => Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _isBusy
                                      ? null
                                      : () => _executer(() => ContainerActions
                                          .ouvrir(context, ref,
                                              cheminPredefini: chemin)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_outlined,
                                            size: 18,
                                            color: AppColors.textSecondary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p.basename(chemin),
                                            style: AppTextStyles.body,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Version ${AppIdentity.version}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
