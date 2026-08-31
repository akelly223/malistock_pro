import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/document_input.dart';
import '../../presentation/commercial_documents/providers/document_form_notifier.dart';
import 'article_autocomplete_field.dart';
import 'document_ligne_tile.dart';

/// Éditeur de lignes d'un document commercial.
///
/// Intègre la recherche article avec autocomplétion et la liste des
/// lignes déjà saisies, chacune éditable via [DocumentLigneTile].
///
/// [onSearchArticle] — délégué fourni par le FormScreen, qui utilise
/// [ArticleRepository.searchArticles] (évite de coupler ce widget à Riverpod).
class DocumentLinesEditor extends StatelessWidget {
  final List<DocumentLigneFormItem> lignes;
  final Future<List<ArticleEntity>> Function(String query) onSearchArticle;
  final void Function(DocumentLigneInput) onAjouter;
  final void Function(int index, DocumentLigneInput) onMettreAJour;
  final void Function(int index) onSupprimer;
  final bool readOnly;

  /// Articles récemment vendus, affichés en raccourcis cliquables
  /// au-dessus du champ de recherche. Vide ou omis = rien n'est affiché.
  final List<ArticleEntity> articlesRecents;

  const DocumentLinesEditor({
    super.key,
    required this.lignes,
    required this.onSearchArticle,
    required this.onAjouter,
    required this.onMettreAJour,
    required this.onSupprimer,
    this.readOnly = false,
    this.articlesRecents = const [],
  });

  void _ajouterArticle(ArticleEntity article) {
    // TVA maintenant gérée au niveau du document : on force tauxTva = 0.
    onAjouter(DocumentLigneInput(
      articleId: article.id,
      articleCode: article.code,
      articleNom: article.nom,
      quantite: 1,
      prixUnitaireHt: article.prixVente,
      tauxTva: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête section ────────────────────────────────────────────
        Row(
          children: [
            Text('Articles', style: AppTextStyles.h3),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${lignes.length} ligne${lignes.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Champ de recherche article (masqué en lecture seule) ───────
        if (!readOnly) ...[
          ArticleAutocompleteField(
            label: 'Ajouter un article',
            onSearch: onSearchArticle,
            onSelected: _ajouterArticle,
          ),
          if (articlesRecents.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ArticlesRecents(
              articles: articlesRecents,
              onSelected: _ajouterArticle,
            ),
          ],
          const SizedBox(height: 16),
        ],

        // ── Liste des lignes ───────────────────────────────────────────
        if (lignes.isEmpty)
          _EmptyLines(readOnly: readOnly)
        else
          Column(
            children: [
              _EnteteTableau(),
              const SizedBox(height: 8),
              for (var i = 0; i < lignes.length; i++)
                DocumentLigneTile(
                  key: ValueKey('ligne-$i-${lignes[i].input.articleId}'),
                  item: lignes[i],
                  index: i,
                  onChanged: (updated) => onMettreAJour(i, updated),
                  onRemove: readOnly ? () {} : () => onSupprimer(i),
                ),
            ],
          ),
      ],
    );
  }
}

class _EnteteTableau extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: const [
          Expanded(flex: 4, child: _ColHeader('Article')),
          SizedBox(width: 10),
          SizedBox(width: 70, child: _ColHeader('Qté', right: true)),
          SizedBox(width: 10),
          SizedBox(width: 110, child: _ColHeader('Prix HT', right: true)),
          SizedBox(width: 10),
          SizedBox(width: 80, child: _ColHeader('Remise %', right: true)),
          Spacer(),
          SizedBox(width: 120, child: _ColHeader('Total HT', right: true)),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final bool right;
  const _ColHeader(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  final bool readOnly;
  const _EmptyLines({required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              readOnly
                  ? 'Aucune ligne dans ce document'
                  : 'Tapez un nom d\'article ci-dessus pour commencer',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Raccourcis vers les articles récemment vendus dans ce magasin : un tap
/// ajoute directement l'article, comme une sélection dans les suggestions.
class _ArticlesRecents extends StatelessWidget {
  final List<ArticleEntity> articles;
  final void Function(ArticleEntity) onSelected;

  const _ArticlesRecents({required this.articles, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: articles.map((article) {
        return ActionChip(
          avatar: const Icon(Icons.history_rounded, size: 16),
          label: Text(article.nom),
          onPressed: () => onSelected(article),
        );
      }).toList(),
    );
  }
}
