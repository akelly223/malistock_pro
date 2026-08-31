import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../../domain/entities/document_input.dart';
import '../../presentation/commercial_documents/providers/document_form_notifier.dart';

/// Ligne éditable d'un document commercial V2.
///
/// Affiche quantité, prix HT, remise % et total HT.
/// La TVA n'est plus gérée par ligne mais au niveau du document
/// (cf. [DocumentTotalsFooter]).
class DocumentLigneTile extends StatefulWidget {
  final DocumentLigneFormItem item;
  final int index;
  final ValueChanged<DocumentLigneInput> onChanged;
  final VoidCallback onRemove;

  const DocumentLigneTile({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<DocumentLigneTile> createState() => _DocumentLigneTileState();
}

class _DocumentLigneTileState extends State<DocumentLigneTile> {
  late TextEditingController _qteCtrl;
  late TextEditingController _prixCtrl;
  late TextEditingController _remiseCtrl;

  DocumentLigneInput get _input => widget.item.input;

  @override
  void initState() {
    super.initState();
    _qteCtrl = TextEditingController(
        text: _input.quantite
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'\.00$'), ''));
    _prixCtrl =
        TextEditingController(text: _input.prixUnitaireHt.toStringAsFixed(0));
    _remiseCtrl = TextEditingController(
        text: _input.remiseLignePct > 0
            ? _input.remiseLignePct.toStringAsFixed(1)
            : '');
  }

  @override
  void didUpdateWidget(DocumentLigneTile old) {
    super.didUpdateWidget(old);
    if (old.item.input.quantite != widget.item.input.quantite) {
      _qteCtrl.text = _input.quantite
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.00$'), '');
    }
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _prixCtrl.dispose();
    _remiseCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final qte = double.tryParse(_qteCtrl.text) ?? _input.quantite;
    final prix = double.tryParse(_prixCtrl.text) ?? _input.prixUnitaireHt;
    final remise = double.tryParse(_remiseCtrl.text) ?? 0;
    widget.onChanged(_input.copyWith(
      quantite: qte <= 0 ? 1 : qte,
      prixUnitaireHt: prix,
      remiseLignePct: remise,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totaux = widget.item.totaux;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : article + bouton suppression ────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _input.articleCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_input.articleNom, style: AppTextStyles.bodyBold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.danger, size: 20),
                onPressed: widget.onRemove,
                tooltip: 'Retirer cette ligne',
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Corps : Qté / Prix HT / Remise / Total HT ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Quantité
              _ChampNumerique(
                label: 'Qté',
                controller: _qteCtrl,
                width: 70,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(width: 10),

              // Prix unitaire HT
              _ChampNumerique(
                label: 'Prix HT',
                controller: _prixCtrl,
                width: 110,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(width: 10),

              // Remise %
              _ChampNumerique(
                label: 'Remise %',
                controller: _remiseCtrl,
                width: 80,
                onChanged: (_) => _emit(),
              ),
              const Spacer(),

              // Total HT
              Text(
                CurrencyFormatter.format(totaux.totalHt),
                style: AppTextStyles.bodyBold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChampNumerique extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double width;
  final ValueChanged<String> onChanged;

  const _ChampNumerique({
    required this.label,
    required this.controller,
    required this.width,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
