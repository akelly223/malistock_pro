import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../../domain/entities/cart_item_input.dart';

/// Ligne de panier éditable, partagée entre les écrans Devis et
/// Vente pour garantir un comportement strictement identique : champ
/// quantité modifiable au clavier, boutons +/- pour l'incrémenter ou
/// la décrémenter, remise par ligne, et recalcul automatique du total
/// de la ligne à chaque changement.
class CartLineTile extends StatefulWidget {
  final CartItemInput item;
  final void Function(CartItemInput) onChanged;
  final VoidCallback onRemove;

  /// Stock réellement disponible pour cet article dans le magasin
  /// sélectionné. Si renseigné et que la quantité du panier le
  /// dépasse, la ligne s'affiche en alerte (bordure et texte rouges).
  /// Laissé à null pour les devis, où aucune réservation de stock
  /// n'a lieu et où dépasser le stock actuel n'est pas une erreur.
  final double? stockDisponible;

  const CartLineTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
    this.stockDisponible,
  });

  @override
  State<CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<CartLineTile> {
  late TextEditingController _quantiteController;
  late TextEditingController _prixController;
  late TextEditingController _remiseController;

  @override
  void initState() {
    super.initState();
    _quantiteController =
        TextEditingController(text: widget.item.quantite.toStringAsFixed(0));
    _prixController =
        TextEditingController(text: widget.item.prixUnitaire.toStringAsFixed(0));
    _remiseController = TextEditingController(
        text: widget.item.remiseMontant == 0
            ? ''
            : widget.item.remiseMontant.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(CartLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final quantiteAffichee = double.tryParse(_quantiteController.text);
    if (quantiteAffichee != widget.item.quantite) {
      _quantiteController.text = widget.item.quantite.toStringAsFixed(0);
    }
    final prixAffiche = double.tryParse(_prixController.text);
    if (prixAffiche != widget.item.prixUnitaire) {
      _prixController.text = widget.item.prixUnitaire.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixController.dispose();
    _remiseController.dispose();
    super.dispose();
  }

  double get _prixSaisi =>
      double.tryParse(_prixController.text) ?? widget.item.prixUnitaire;

  void _emettreChangement({double? qte, double? remise}) {
    widget.onChanged(CartItemInput(
      articleId: widget.item.articleId,
      articleNom: widget.item.articleNom,
      quantite: qte ?? widget.item.quantite,
      prixUnitaire: _prixSaisi,
      remisePourcentage: widget.item.remisePourcentage,
      remiseMontant: remise ?? widget.item.remiseMontant,
    ));
  }

  void _onChampQuantiteModifie(String value) {
    final qte = double.tryParse(value) ?? widget.item.quantite;
    _emettreChangement(qte: qte <= 0 ? 1 : qte);
  }

  void _incrementer() {
    final q = widget.item.quantite + 1;
    _quantiteController.text = q.toStringAsFixed(0);
    _emettreChangement(qte: q);
  }

  void _decrementer() {
    final q = widget.item.quantite - 1;
    if (q <= 0) return;
    _quantiteController.text = q.toStringAsFixed(0);
    _emettreChangement(qte: q);
  }

  void _onChampPrixModifie(String _) => _emettreChangement();

  void _onChampRemiseModifie(String value) {
    _emettreChangement(remise: double.tryParse(value) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final stockInsuffisant = widget.stockDisponible != null &&
        widget.item.quantite > widget.stockDisponible!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stockInsuffisant ? AppColors.dangerLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stockInsuffisant ? AppColors.danger : AppColors.border,
          width: stockInsuffisant ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.articleNom, style: AppTextStyles.bodyBold),
                    if (widget.stockDisponible != null)
                    Row(
                      children: [
                        if (widget.stockDisponible != null) ...[
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 12,
                            color: stockInsuffisant
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Stock: ${widget.stockDisponible!.toStringAsFixed(0)}',
                            style: AppTextStyles.caption.copyWith(
                              color: stockInsuffisant
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                              fontWeight: stockInsuffisant
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Bloc quantité : boutons +/- entourant un champ modifiable
              // directement au clavier, les deux modes restent toujours
              // synchronisés entre eux.
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: stockInsuffisant
                          ? AppColors.danger
                          : AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: _decrementer,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Diminuer la quantité',
                    ),
                    SizedBox(
                      width: 44,
                      child: TextField(
                        controller: _quantiteController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: stockInsuffisant ? AppColors.danger : null,
                          fontWeight:
                              stockInsuffisant ? FontWeight.w700 : null,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: _onChampQuantiteModifie,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: _incrementer,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Augmenter la quantité',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _prixController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Prix unitaire'),
                  onChanged: _onChampPrixModifie,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _remiseController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Remise'),
                  onChanged: _onChampRemiseModifie,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  CurrencyFormatter.format(widget.item.totalLigne),
                  style: AppTextStyles.bodyBold,
                  textAlign: TextAlign.right,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                onPressed: widget.onRemove,
                tooltip: 'Retirer cet article',
              ),
            ],
          ),
          if (stockInsuffisant) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Text(
                  'Stock insuffisant : ${widget.stockDisponible!.toStringAsFixed(0)} disponible(s) seulement',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
