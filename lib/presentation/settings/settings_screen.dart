import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/constants/app_identity.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/logo_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/permissions/permissions.dart';
import '../../app/providers/session_provider.dart';
import '../../domain/entities/app_settings.dart';
import 'providers/settings_provider.dart';
import 'providers/backup_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Identité ──────────────────────────────────────────────────────
  final _nomController = TextEditingController();
  final _sloganController = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();

  // ── Fiscalité ────────────────────────────────────────────────────
  final _nifController = TextEditingController();
  final _rccmController = TextEditingController();
  final _ifuController = TextEditingController();
  bool _tvaActive = false;
  final _tauxTvaController = TextEditingController();
  String _devise = 'FCFA';

  // ── Documents ────────────────────────────────────────────────────
  final _commentaireController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialised = false;
  bool _isBackupRunning = false;
  bool _isLogoLoading = false;
  bool _isSignatureLoading = false;
  bool _isCachetLoading = false;

  static const _devises = ['FCFA', 'USD', 'EUR', 'XOF', 'GNF', 'MAD'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nomController.dispose();
    _sloganController.dispose();
    _telController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _nifController.dispose();
    _rccmController.dispose();
    _ifuController.dispose();
    _tauxTvaController.dispose();
    _commentaireController.dispose();
    super.dispose();
  }

  void _initialiserChamps(AppSettingsEntity s) {
    if (_isInitialised) return;
    _nomController.text = s.nomEntreprise;
    _telController.text = s.telephone ?? '';
    _adresseController.text = s.adresse ?? '';
    _emailController.text = s.email ?? '';
    _sloganController.text = s.slogan ?? '';
    _commentaireController.text = s.commentairePiedDePage;
    _nifController.text = s.nif ?? '';
    _rccmController.text = s.rccm ?? '';
    _ifuController.text = s.ifu ?? '';
    _tvaActive = s.tvaActive;
    _tauxTvaController.text = s.tauxTva.toStringAsFixed(0);
    _devise = _devises.contains(s.devise) ? s.devise : 'FCFA';
    _isInitialised = true;
  }

  String? _optionnel(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _enregistrer() async {
    setState(() => _isLoading = true);
    final repo = ref.read(settingsRepositoryProvider);
    try {
      await repo.updateSettings(
        nomEntreprise: _nomController.text.trim().isEmpty
            ? 'Ma Boutique'
            : _nomController.text.trim(),
        telephone: _optionnel(_telController),
        adresse: _optionnel(_adresseController),
        email: _optionnel(_emailController),
        slogan: _optionnel(_sloganController),
        commentairePiedDePage: _optionnel(_commentaireController),
        nif: _optionnel(_nifController),
        rccm: _optionnel(_rccmController),
        ifu: _optionnel(_ifuController),
        tvaActive: _tvaActive,
        tauxTva: double.tryParse(_tauxTvaController.text) ?? 18.0,
        devise: _devise,
      );
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres enregistrés avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logo ─────────────────────────────────────────────────────────

  Future<void> _importerLogo(String? actuel) async {
    final f = await _choisirImage('Sélectionner le logo');
    if (f == null) return;
    setState(() => _isLogoLoading = true);
    try {
      final path = await LogoService.importerLogo(f);
      await ref.read(settingsRepositoryProvider).updateSettings(logoPath: path);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Logo mis à jour.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isLogoLoading = false);
    }
  }

  Future<void> _retirerLogo(String? actuel) async {
    if (!await _confirmerRetrait('logo')) return;
    setState(() => _isLogoLoading = true);
    await LogoService.supprimerLogo(actuel);
    await ref
        .read(settingsRepositoryProvider)
        .updateSettings(supprimerLogo: true);
    ref.invalidate(appSettingsProvider);
    if (mounted) setState(() => _isLogoLoading = false);
  }

  // ── Signature ────────────────────────────────────────────────────

  Future<void> _importerSignature() async {
    final f = await _choisirImage('Sélectionner la signature');
    if (f == null) return;
    setState(() => _isSignatureLoading = true);
    try {
      final path = await LogoService.importerSignature(f);
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(signaturePath: path);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signature mise à jour.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isSignatureLoading = false);
    }
  }

  Future<void> _retirerSignature(String? actuel) async {
    if (!await _confirmerRetrait('signature')) return;
    setState(() => _isSignatureLoading = true);
    await LogoService.supprimerSignature(actuel);
    await ref
        .read(settingsRepositoryProvider)
        .updateSettings(supprimerSignature: true);
    ref.invalidate(appSettingsProvider);
    if (mounted) setState(() => _isSignatureLoading = false);
  }

  // ── Cachet ───────────────────────────────────────────────────────

  Future<void> _importerCachet() async {
    final f = await _choisirImage('Sélectionner le cachet');
    if (f == null) return;
    setState(() => _isCachetLoading = true);
    try {
      final path = await LogoService.importerCachet(f);
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(cachetPath: path);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cachet mis à jour.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isCachetLoading = false);
    }
  }

  Future<void> _retirerCachet(String? actuel) async {
    if (!await _confirmerRetrait('cachet')) return;
    setState(() => _isCachetLoading = true);
    await LogoService.supprimerCachet(actuel);
    await ref
        .read(settingsRepositoryProvider)
        .updateSettings(supprimerCachet: true);
    ref.invalidate(appSettingsProvider);
    if (mounted) setState(() => _isCachetLoading = false);
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Future<String?> _choisirImage(String titre) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: titre,
    );
    return result?.files.single.path;
  }

  Future<bool> _confirmerRetrait(String type) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ce $type ?'),
        content: Text(
            'Ce $type n\'apparaîtra plus sur vos documents imprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          AppButton(
            label: 'Retirer',
            isDanger: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Sauvegarde ───────────────────────────────────────────────────

  Future<void> _exporterSauvegarde() async {
    setState(() => _isBackupRunning = true);
    final db = ref.read(databaseProvider);
    final resultat = await BackupService.exporterSauvegarde(db);
    if (mounted) setState(() => _isBackupRunning = false);
    ref.invalidate(backupListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultat.succes && resultat.filePath != null
          ? 'Sauvegarde créée : ${resultat.filePath}'
          : resultat.message),
      backgroundColor: resultat.succes ? null : AppColors.danger,
    ));
  }

  Future<void> _importerSauvegarde() async {
    final fichier = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Sélectionner un fichier de sauvegarde (.zip)',
    );
    if (fichier == null || fichier.files.single.path == null) return;
    if (!mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
          'Toutes les données actuelles seront remplacées. '
          'Une copie de sécurité sera conservée automatiquement. '
          'L\'application se fermera après la restauration.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          AppButton(
            label: 'Restaurer',
            isDanger: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isBackupRunning = true);
    final db = ref.read(databaseProvider);
    final resultat =
        await BackupService.restaurerSauvegarde(fichier.files.single.path!, db);
    if (mounted) setState(() => _isBackupRunning = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultat.message),
      backgroundColor: resultat.succes ? null : AppColors.danger,
      duration: const Duration(seconds: 6),
    ));
    if (resultat.succes) {
      await Future.delayed(const Duration(seconds: 3));
      exit(0);
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutGererParametresEntreprise(utilisateur)) {
      return const AccessDeniedView(titre: 'Paramètres');
    }

    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Entreprise'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Fiscalité'),
            Tab(icon: Icon(Icons.image_rounded), text: 'Visuels'),
            Tab(icon: Icon(Icons.save_rounded), text: 'Sauvegarde'),
          ],
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          _initialiserChamps(settings);
          return TabBarView(
            controller: _tabs,
            children: [
              _ongletEntreprise(settings),
              _ongletFiscalite(),
              _ongletVisuels(settings),
              _ongletSauvegarde(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  // ── Onglet 1 : Entreprise ─────────────────────────────────────────

  Widget _ongletEntreprise(AppSettingsEntity settings) {
    return _ScrollPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Identité du commerce'),
          AppTextField(
              label: 'Nom du commerce',
              controller: _nomController,
              hint: 'Ex: Épicerie du Marché Central'),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Slogan',
              controller: _sloganController,
              hint: 'Ex: Alimentation générale - Gros et détail'),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Téléphone',
              controller: _telController,
              hint: 'Ex: +223 76 12 34 56',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Email (optionnel)',
              controller: _emailController,
              hint: 'Ex: contact@boutique.ml',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Adresse',
              controller: _adresseController,
              hint: 'Ex: Hamdallaye ACI 2000, Bamako',
              maxLines: 2),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Commentaire pied de page (facture)',
              controller: _commentaireController,
              hint: 'Ex: Marchandise vendue ni reprise ni échangée.',
              maxLines: 3),
          const SizedBox(height: 24),
          AppButton(
            label: 'Enregistrer',
            icon: Icons.check_circle_outline,
            isLoading: _isLoading,
            onPressed: _enregistrer,
          ),
          const SizedBox(height: 36),
          _AppVersion(),
        ],
      ),
    );
  }

  // ── Onglet 2 : Fiscalité ──────────────────────────────────────────

  Widget _ongletFiscalite() {
    return _ScrollPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Identifiants fiscaux'),
          Text(
            'Ces identifiants apparaissent sur vos factures officielles.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          AppTextField(
              label: 'NIF (Numéro d\'Identification Fiscale)',
              controller: _nifController,
              hint: 'Ex: 123456789'),
          const SizedBox(height: 14),
          AppTextField(
              label: 'RCCM (Registre du Commerce)',
              controller: _rccmController,
              hint: 'Ex: BKO/2020/B/1234'),
          const SizedBox(height: 14),
          AppTextField(
              label: 'IFU (optionnel)',
              controller: _ifuController,
              hint: 'Ex: 0000123456'),
          const SizedBox(height: 28),
          _SectionTitle('TVA'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Appliquer la TVA sur les ventes',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      _tvaActive
                          ? 'La TVA sera calculée sur chaque facture.'
                          : 'Ventes sans TVA (régime forfaitaire).',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _tvaActive,
                onChanged: (v) => setState(() => _tvaActive = v),
              ),
            ],
          ),
          if (_tvaActive) ...[
            const SizedBox(height: 14),
            AppTextField(
              label: 'Taux TVA (%)',
              controller: _tauxTvaController,
              hint: 'Ex: 18',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle('Devise'),
          DropdownButtonFormField<String>(
            initialValue: _devise,
            decoration:
                const InputDecoration(labelText: 'Devise utilisée'),
            items: _devises
                .map((d) =>
                    DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _devise = v ?? 'FCFA'),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Enregistrer',
            icon: Icons.check_circle_outline,
            isLoading: _isLoading,
            onPressed: _enregistrer,
          ),
        ],
      ),
    );
  }

  // ── Onglet 3 : Visuels ────────────────────────────────────────────

  Widget _ongletVisuels(AppSettingsEntity settings) {
    return _ScrollPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Logo'),
          Text('Affiché en haut de vos factures et documents imprimés.',
              style: AppTextStyles.caption),
          const SizedBox(height: 16),
          _ImagePicker(
            chemin: settings.logoPath,
            placeholder: Icons.add_photo_alternate_outlined,
            isLoading: _isLogoLoading,
            onImporter: () => _importerLogo(settings.logoPath),
            onRetirer: settings.logoPath != null
                ? () => _retirerLogo(settings.logoPath)
                : null,
            labelImporter: settings.logoPath != null
                ? 'Changer le logo'
                : 'Importer un logo',
          ),
          const SizedBox(height: 32),
          _SectionTitle('Signature'),
          Text(
            'Image de votre signature manuscrite (PNG fond transparent recommandé). '
            'Apparaît en bas de vos documents.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          _ImagePicker(
            chemin: settings.signaturePath,
            placeholder: Icons.draw_outlined,
            isLoading: _isSignatureLoading,
            onImporter: _importerSignature,
            onRetirer: settings.signaturePath != null
                ? () => _retirerSignature(settings.signaturePath)
                : null,
            labelImporter: settings.signaturePath != null
                ? 'Changer la signature'
                : 'Importer une signature',
          ),
          const SizedBox(height: 32),
          _SectionTitle('Cachet / Tampon'),
          Text(
            'Photo ou scan de votre cachet officiel. '
            'Affiché à côté de la signature.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          _ImagePicker(
            chemin: settings.cachetPath,
            placeholder: Icons.approval_outlined,
            isLoading: _isCachetLoading,
            onImporter: _importerCachet,
            onRetirer: settings.cachetPath != null
                ? () => _retirerCachet(settings.cachetPath)
                : null,
            labelImporter: settings.cachetPath != null
                ? 'Changer le cachet'
                : 'Importer un cachet',
          ),
        ],
      ),
    );
  }

  // ── Onglet 4 : Sauvegarde ─────────────────────────────────────────

  Widget _ongletSauvegarde() {
    return _ScrollPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Sauvegarde des données'),
          Text(
            'Exportez une copie complète de vos données ou restaurez une '
            'sauvegarde précédente. Conservez vos sauvegardes sur une clé '
            'USB ou un autre disque.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              AppButton(
                label: 'Exporter (.zip)',
                icon: Icons.download_rounded,
                isOutlined: true,
                isLoading: _isBackupRunning,
                onPressed: _exporterSauvegarde,
              ),
              AppButton(
                label: 'Importer une sauvegarde',
                icon: Icons.upload_rounded,
                isOutlined: true,
                isLoading: _isBackupRunning,
                onPressed: _importerSauvegarde,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer(builder: (context, ref, _) {
            final backupsAsync = ref.watch(backupListProvider);
            return backupsAsync.when(
              data: (fichiers) {
                if (fichiers.isEmpty) {
                  return Text('Aucune sauvegarde créée pour l\'instant.',
                      style: AppTextStyles.caption);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sauvegardes récentes', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 10),
                    ...fichiers.take(5).map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            const Icon(Icons.archive_outlined,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                style: AppTextStyles.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormatter.formatDateTime(
                                  f.statSync().modified),
                              style: AppTextStyles.caption,
                            ),
                          ]),
                        )),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          }),
          const SizedBox(height: 36),
          _SectionTitle('Mises à jour'),
          Text('Version actuelle : ${AppIdentity.version}',
              style: AppTextStyles.caption),
          const SizedBox(height: 12),
          AppButton(
            label: 'Vérifier les mises à jour',
            icon: Icons.system_update_alt_rounded,
            isOutlined: true,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Vous utilisez la version ${AppIdentity.version}. '
                    'La vérification automatique sera disponible prochainement.'),
                duration: const Duration(seconds: 4),
              ));
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          _SectionTitle('Informations'),
          _CarteNavigation(
            icon: Icons.import_export_rounded,
            couleur: AppColors.secondary,
            titre: 'Migration des données',
            sousTitre:
                'Importer articles, clients, fournisseurs depuis Sage ou Excel',
            onTap: () => context.push('/migration'),
          ),
          const SizedBox(height: 10),
          _CarteNavigation(
            icon: Icons.info_outline_rounded,
            couleur: AppColors.primary,
            titre: 'À propos de MaliStock Pro',
            sousTitre: 'Version, éditeur, licence, contact',
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────

class _ScrollPane extends StatelessWidget {
  final Widget child;
  const _ScrollPane({required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String titre;
  const _SectionTitle(this.titre);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(titre, style: AppTextStyles.h3),
      );
}

class _AppVersion extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        const Divider(),
        const SizedBox(height: 16),
        Center(
          child: Column(children: [
            Text(AppIdentity.editeur,
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(AppIdentity.sloganEditeur, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(AppIdentity.paysEditeur, style: AppTextStyles.caption),
          ]),
        ),
        const SizedBox(height: 16),
      ]);
}

class _CarteNavigation extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  const _CarteNavigation({
    required this.icon,
    required this.couleur,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: couleur, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(sousTitre,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final String? chemin;
  final IconData placeholder;
  final bool isLoading;
  final VoidCallback onImporter;
  final VoidCallback? onRetirer;
  final String labelImporter;

  const _ImagePicker({
    required this.chemin,
    required this.placeholder,
    required this.isLoading,
    required this.onImporter,
    required this.onRetirer,
    required this.labelImporter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 90,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: chemin != null
              ? Image.file(File(chemin!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
                      size: 32, color: AppColors.primary))
              : Icon(placeholder, size: 32, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppButton(
                label: labelImporter,
                icon: Icons.upload_rounded,
                isOutlined: true,
                isLoading: isLoading,
                onPressed: onImporter,
              ),
              if (onRetirer != null) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Retirer',
                  icon: Icons.delete_outline,
                  isOutlined: true,
                  isDanger: true,
                  isLoading: isLoading,
                  onPressed: onRetirer,
                ),
              ],
              const SizedBox(height: 6),
              Text('PNG ou JPG recommandé. Fond transparent pour signature/cachet.',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
