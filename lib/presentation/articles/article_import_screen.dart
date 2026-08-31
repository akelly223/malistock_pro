import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/services/article_import_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/permissions/permissions.dart';
import '../../presentation/stores/providers/store_provider.dart';
import 'providers/article_import_provider.dart';

final _numFmt = NumberFormat.decimalPattern('fr_FR');

class ArticleImportScreen extends ConsumerWidget {
  const ArticleImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutImporterDonnees(utilisateur)) {
      return const AccessDeniedView(titre: 'Importer des articles');
    }

    final state = ref.watch(articleImportProvider);
    final peutVoirPrixAchat = Permissions.peutVoirPrixAchat(utilisateur);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des articles'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildBody(context, ref, state, peutVoirPrixAchat),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      ArticleImportState state, bool peutVoirPrixAchat) {
    if (state.isImporting) return _buildProgressView(state);
    if (state.resultat != null) return _buildResultatView(context, ref, state);
    if (state.isLoading) return _buildLoadingView();
    if (state.hasParsedRows) {
      return _buildApercu(context, ref, state, peutVoirPrixAchat);
    }
    return _buildSelectionFichier(context, ref, state);
  }

  // ─── Phase 1 : sélection du fichier ────────────────────────────────────────

  Widget _buildSelectionFichier(
      BuildContext context, WidgetRef ref, ArticleImportState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withAlpha(80),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(Icons.upload_file_rounded,
                        size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('Importer depuis Sage', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez un fichier TXT ou CSV exporté\ndepuis Sage Gestion Commerciale.',
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Format attendu : Code | Famille | Désignation | Prix achat | Prix vente',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Sélectionner un fichier',
                    icon: Icons.folder_open_rounded,
                    width: 260,
                    onPressed: () => _choisirFichier(ref),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErreurBandeau(state.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _choisirFichier(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      dialogTitle: 'Sélectionner le fichier articles',
    );
    if (result == null || result.files.single.path == null) return;
    await ref
        .read(articleImportProvider.notifier)
        .chargerFichier(result.files.single.path!);
  }

  // ─── Phase 2 : chargement ───────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Analyse du fichier en cours…'),
        ],
      ),
    );
  }

  // ─── Phase 3 : aperçu + configuration ──────────────────────────────────────

  Widget _buildApercu(BuildContext context, WidgetRef ref,
      ArticleImportState state, bool peutVoirPrixAchat) {
    final rows = state.parsedRows;
    final previewRows = rows.take(50).toList();
    final nbTotal = rows.length;
    final nbDoublons = state.codesDoublons.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé
          _buildSummaryBanner(ref, nbTotal, nbDoublons),
          const SizedBox(height: 20),

          // Tableau aperçu
          Text('Aperçu du fichier', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _buildPreviewTable(previewRows, peutVoirPrixAchat),
          if (nbTotal > 50)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Aperçu des 50 premiers articles sur ${_numFmt.format(nbTotal)}',
                style: AppTextStyles.caption,
              ),
            ),
          const SizedBox(height: 28),

          // Options
          _buildOptions(context, ref, state),
          const SizedBox(height: 28),

          // Bouton importer
          _buildBoutonImport(context, ref, state),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(WidgetRef ref, int nbTotal, int nbDoublons) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.body,
                children: [
                  TextSpan(
                    text: '${_numFmt.format(nbTotal)} articles détectés',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (nbDoublons > 0)
                    TextSpan(
                      text:
                          '  ·  ${_numFmt.format(nbDoublons)} déjà présents en base',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Changer de fichier'),
            onPressed: () => _choisirFichier(ref),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(
      List<ArticleImportRow> rows, bool peutVoirPrixAchat) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(AppColors.background),
            columnSpacing: 24,
            columns: [
              const DataColumn(
                  label: Text('Code', style: AppTextStyles.bodyBold)),
              const DataColumn(
                  label: Text('Désignation', style: AppTextStyles.bodyBold)),
              if (peutVoirPrixAchat)
                const DataColumn(
                    label: Text('Prix achat', style: AppTextStyles.bodyBold),
                    numeric: true),
              const DataColumn(
                  label: Text('Prix vente', style: AppTextStyles.bodyBold),
                  numeric: true),
            ],
            rows: rows
                .map((r) => DataRow(cells: [
                      DataCell(Text(r.code,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600))),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(r.nom,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ),
                      ),
                      if (peutVoirPrixAchat)
                        DataCell(Text('${_numFmt.format(r.prixAchat)} FCFA',
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                      DataCell(Text('${_numFmt.format(r.prixVente)} FCFA',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary))),
                    ]))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildOptions(
      BuildContext context, WidgetRef ref, ArticleImportState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gestion des doublons ──
        if (state.hasDoublons) ...[
          _buildSectionTitle(
              'Gestion des doublons',
              '${_numFmt.format(state.codesDoublons.length)} articles déjà présents',
              Icons.content_copy_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _radioDoublon(ref, state, DoublonStrategie.ignorer,
                    'Ignorer', 'Ne pas modifier les articles existants'),
                _radioDoublon(ref, state, DoublonStrategie.mettreAJour,
                    'Mettre à jour',
                    'Remplacer le nom, le prix achat et le prix vente'),
                _radioDoublon(
                    ref,
                    state,
                    DoublonStrategie.demanderChaque,
                    'Choisir pour chaque article',
                    'Définir une action individuelle ci-dessous'),
              ],
            ),
          ),

          // Section per-article si demanderChaque
          if (state.doublonStrategie == DoublonStrategie.demanderChaque) ...[
            const SizedBox(height: 16),
            _buildDemanderChaqueListe(ref, state),
          ],

          const SizedBox(height: 24),
        ],

        // ── Stock initial ──
        if (state.hasStockColumn) ...[
          _buildSectionTitle('Stock initial', null, Icons.inventory_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: state.importerAvecStock,
                  onChanged: (v) => ref
                      .read(articleImportProvider.notifier)
                      .setImporterAvecStock(v ?? false),
                  title: const Text('Importer les articles avec leur stock initial'),
                  subtitle: const Text(
                    'Le stock sera ajouté dans le magasin sélectionné.',
                    style: AppTextStyles.caption,
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.importerAvecStock) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildStoreSelector(ref, state),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _radioDoublon(WidgetRef ref, ArticleImportState state,
      DoublonStrategie valeur, String titre, String sousTitre) {
    return RadioListTile<DoublonStrategie>(
      value: valeur,
      groupValue: state.doublonStrategie,
      onChanged: (v) => ref
          .read(articleImportProvider.notifier)
          .setDoublonStrategie(v!),
      title: Text(titre, style: AppTextStyles.body),
      subtitle: Text(sousTitre, style: AppTextStyles.caption),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDemanderChaqueListe(
      WidgetRef ref, ArticleImportState state) {
    final doublesRows = state.parsedRows
        .where((r) => state.codesDoublons.contains(r.code))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choisir une action pour chaque doublon',
                  style: AppTextStyles.bodyBold,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doublesRows.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final row = doublesRows[i];
              final strategie = state.strategieParArticle[row.code] ??
                  DoublonStrategie.ignorer;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.code,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700)),
                          Text(row.nom,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<DoublonStrategie>(
                      value: strategie,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: DoublonStrategie.ignorer,
                          child: Text('Ignorer'),
                        ),
                        DropdownMenuItem(
                          value: DoublonStrategie.mettreAJour,
                          child: Text('Mettre à jour'),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(articleImportProvider.notifier)
                          .setStrategieParArticle(row.code, v!),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector(WidgetRef ref, ArticleImportState state) {
    final storesAsync = ref.watch(storesListProvider);

    return storesAsync.when(
      data: (stores) {
        if (stores.isEmpty) {
          return Text(
            'Aucun magasin disponible. Créez d\'abord un magasin.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.danger),
          );
        }
        final selected = state.selectedStoreId ?? stores.first.id;
        // Initialiser la sélection par défaut si besoin
        if (state.selectedStoreId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(articleImportProvider.notifier)
                .setSelectedStore(stores.first.id);
          });
        }
        return DropdownButtonFormField<int>(
          value: stores.any((s) => s.id == selected)
              ? selected
              : stores.first.id,
          decoration: const InputDecoration(
            labelText: 'Magasin de destination',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.store_rounded),
          ),
          items: stores
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.nom),
                  ))
              .toList(),
          onChanged: (id) =>
              ref.read(articleImportProvider.notifier).setSelectedStore(id),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur chargement magasins : $e'),
    );
  }

  Widget _buildBoutonImport(
      BuildContext context, WidgetRef ref, ArticleImportState state) {
    final nbTotal = state.parsedRows.length;
    final peutImporter = nbTotal > 0 &&
        (!state.importerAvecStock || state.selectedStoreId != null);

    return Row(
      children: [
        AppButton(
          label: 'Importer ${_numFmt.format(nbTotal)} articles',
          icon: Icons.download_rounded,
          width: 280,
          onPressed: peutImporter
              ? () => ref.read(articleImportProvider.notifier).lancerImport()
              : null,
        ),
        const SizedBox(width: 16),
        AppButton(
          label: 'Annuler',
          icon: Icons.close_rounded,
          isOutlined: true,
          onPressed: () {
            ref.read(articleImportProvider.notifier).reinitialiser();
          },
        ),
      ],
    );
  }

  // ─── Phase 4 : import en cours ─────────────────────────────────────────────

  Widget _buildProgressView(ArticleImportState state) {
    final done = (state.importProgress * state.parsedRows.length).round();
    final total = state.parsedRows.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_rounded,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 20),
            Text('Import en cours…', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              '${_numFmt.format(done)} / ${_numFmt.format(total)} articles traités',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.importProgress,
                minHeight: 12,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(state.importProgress * 100).toStringAsFixed(0)} %',
              style: AppTextStyles.bodyBold,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Phase 5 : résultat ────────────────────────────────────────────────────

  Widget _buildResultatView(
      BuildContext context, WidgetRef ref, ArticleImportState state) {
    final r = state.resultat!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône succès / avertissement
            Icon(
              r.erreurs.isEmpty
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              size: 56,
              color: r.erreurs.isEmpty ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              r.erreurs.isEmpty ? 'Import terminé' : 'Import terminé avec des erreurs',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Tuiles résumé
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tuileResultat(
                      '${_numFmt.format(r.importes)}',
                      'Articles importés',
                      AppColors.success,
                      AppColors.successLight,
                      Icons.add_circle_rounded),
                  const SizedBox(width: 12),
                  _tuileResultat(
                      '${_numFmt.format(r.misAJour)}',
                      'Mis à jour',
                      AppColors.secondary,
                      AppColors.secondaryLight,
                      Icons.update_rounded),
                  const SizedBox(width: 12),
                  _tuileResultat(
                      '${_numFmt.format(r.ignores)}',
                      'Ignorés',
                      AppColors.textSecondary,
                      AppColors.background,
                      Icons.skip_next_rounded),
                  const SizedBox(width: 12),
                  _tuileResultat(
                      '${r.erreurs.length}',
                      'Erreurs',
                      AppColors.danger,
                      AppColors.dangerLight,
                      Icons.error_outline_rounded),
                ],
              ),
            ),

            // Détail des erreurs
            if (r.erreurs.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildErreurDetails(r.erreurs),
            ],

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Nouvel import',
                  icon: Icons.upload_file_rounded,
                  isOutlined: true,
                  onPressed: () =>
                      ref.read(articleImportProvider.notifier).reinitialiser(),
                ),
                const SizedBox(width: 16),
                AppButton(
                  label: 'Voir les articles',
                  icon: Icons.inventory_2_rounded,
                  onPressed: () => context.go('/articles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tuileResultat(String valeur, String label, Color couleur,
      Color fond, IconData icone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icone, color: couleur, size: 28),
            const SizedBox(height: 8),
            Text(valeur,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: couleur)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErreurDetails(List<String> erreurs) {
    return ExpansionTile(
      title: Text(
        'Détail des erreurs (${erreurs.length})',
        style: AppTextStyles.bodyBold
            .copyWith(color: AppColors.danger),
      ),
      leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
      backgroundColor: AppColors.dangerLight,
      collapsedBackgroundColor: AppColors.dangerLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      children: erreurs
          .map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.danger),
                title: Text(e, style: AppTextStyles.caption),
              ))
          .toList(),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String titre, String? sous, IconData icone) {
    return Row(
      children: [
        Icon(icone, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(titre, style: AppTextStyles.h3),
        if (sous != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(sous,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _buildErreurBandeau(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.danger))),
        ],
      ),
    );
  }
}
