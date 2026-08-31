import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../app/theme/app_colors.dart';
import '../../domain/entities/article.dart';

/// Champ de saisie avec suggestion automatique d'articles.
///
/// Implémente l'exigence du cahier des charges : taper "ri" doit
/// proposer "Riz local", "Riz parfumé", "Riz Gambiaka", etc.
/// Un debounce de 250ms évite de lancer une requête à chaque frappe.
///
/// IMPORTANT (fix clic non fonctionnel) : la fermeture de la liste de
/// suggestions est pilotée par [TapRegion], pas par les listeners de
/// focus. Fermer sur perte de focus retire l'OverlayEntry de l'arbre
/// avant que le tap sur un item ne soit résolu (le focus est perdu
/// dès le pointer-down, avant le pointer-up qui déclenche onTap),
/// donc le clic n'atteint jamais le ListTile. TapRegion résout cette
/// course en testant la position réelle du clic plutôt que le focus.
class ArticleAutocompleteField extends StatefulWidget {
  final String label;
  final Future<List<ArticleEntity>> Function(String query) onSearch;
  final void Function(ArticleEntity article) onSelected;
  final String? initialText;

  /// Active la création rapide d'article intégrée : quand fourni, un
  /// item "Créer l'article" apparaît en bas de la liste de suggestions
  /// (ou seul, si aucun article ne correspond). L'implémentation
  /// (ouverture du dialog, sauvegarde) reste entièrement à la charge
  /// de l'appelant — ce widget ne fait qu'exposer le point d'entrée,
  /// pour rester réutilisable partout (achats, ventes, devis...) sans
  /// dupliquer la logique de création.
  final Future<ArticleEntity?> Function(
      BuildContext context, String texteSaisi)? onCreateArticle;

  const ArticleAutocompleteField({
    super.key,
    required this.label,
    required this.onSearch,
    required this.onSelected,
    this.initialText,
    this.onCreateArticle,
  });

  @override
  State<ArticleAutocompleteField> createState() =>
      _ArticleAutocompleteFieldState();
}

class _ArticleAutocompleteFieldState extends State<ArticleAutocompleteField> {
  late final TextEditingController _controller;
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<ArticleEntity> _suggestions = [];
  String _currentQuery = '';
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _currentQuery = value.trim();
    if (_currentQuery.length < 2) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await widget.onSearch(_currentQuery);
      if (!mounted) return;
      setState(() => _suggestions = results);
      // Avec la création rapide activée, on affiche la liste même sans
      // résultat pour proposer "Créer l'article ...".
      if (results.isNotEmpty || widget.onCreateArticle != null) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  /// Sélection d'un article depuis la liste de suggestions.
  ///
  /// Vide le champ et referme la liste immédiatement (avant l'appel à
  /// onSelected) pour un retour visuel instantané, conformément au
  /// comportement demandé : article ajouté, champ vidé, suggestions
  /// fermées.
  void _selectArticle(ArticleEntity article) {
    _removeOverlay();
    _controller.clear();
    widget.onSelected(article);
    // Redonne le focus au champ pour permettre une saisie immédiate
    // de l'article suivant, sans clic supplémentaire.
    _focusNode.requestFocus();
  }

  /// Ouvre la création rapide (déléguée à l'appelant via
  /// [ArticleAutocompleteField.onCreateArticle]) sans jamais quitter
  /// le document en cours. L'article créé est ajouté immédiatement,
  /// exactement comme une sélection normale.
  Future<void> _creerArticle() async {
    final texteSaisi = _currentQuery;
    _removeOverlay();
    final nouvelArticle = await widget.onCreateArticle!(context, texteSaisi);
    if (!mounted) return;
    if (nouvelArticle != null) {
      _selectArticle(nouvelArticle);
    } else {
      // Création annulée : on redonne simplement la main au champ.
      _focusNode.requestFocus();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            // TapRegion : ferme la liste uniquement si le clic tombe
            // hors de cette zone ET hors du champ de texte associé
            // (groupId partagé). C'est ce qui remplace le listener de
            // focus défaillant.
            child: TapRegion(
              groupId: _fieldKey,
              onTapOutside: (_) => _removeOverlay(),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _suggestions.length +
                        (widget.onCreateArticle != null ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      if (index >= _suggestions.length) {
                        return _CreerArticleTile(
                          texteSaisi: _currentQuery,
                          aDesSuggestions: _suggestions.isNotEmpty,
                          onTap: _creerArticle,
                        );
                      }
                      final article = _suggestions[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectArticle(article),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.nom,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${article.code} · Stock: ${article.stockTotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _fieldKey,
      onTapOutside: (_) => _removeOverlay(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Column(
          key: _fieldKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Tapez pour rechercher un article...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de bas de liste ouvrant la création rapide d'article. Le
/// libellé varie selon qu'il existe déjà des suggestions ou non, comme
/// demandé : "Créer l'article "Nom saisi"" quand rien ne correspond,
/// "Nouvel article" quand des suggestions sont déjà affichées.
class _CreerArticleTile extends StatelessWidget {
  final String texteSaisi;
  final bool aDesSuggestions;
  final VoidCallback onTap;

  const _CreerArticleTile({
    required this.texteSaisi,
    required this.aDesSuggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = aDesSuggestions
        ? 'Nouvel article'
        : 'Créer l\'article "$texteSaisi"';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
