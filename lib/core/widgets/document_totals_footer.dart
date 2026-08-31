import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';

/// Récapitulatif financier d'un document : HT / Remise / TVA / TTC.
///
/// Mode lecture (onRemiseChanged == null) : affiche uniquement les lignes
/// non nulles, sans champ de saisie.
///
/// Mode édition (onRemiseChanged != null) : affiche la remise éditable et
/// le bloc TVA avec case à cocher + champ de taux.
class DocumentTotalsFooter extends StatefulWidget {
  final double totalHtBrut;
  final double totalTva;
  final double totalHt;
  final double totalTtc;
  final double remiseGlobalePct;

  /// Taux de TVA global affiché dans le libellé (ex : 18.0 → "TVA (18%)").
  final double tvaGlobalePct;

  /// true si la TVA est appliquée au document.
  final bool appliquerTva;

  // ── Callbacks mode édition (null = lecture seule) ───────────────────────

  final ValueChanged<double>? onRemiseChanged;
  final ValueChanged<bool>? onAppliquerTvaChanged;
  final ValueChanged<double>? onTvaChanged;

  // ── Paiements (vue détail) ───────────────────────────────────────────────

  final double? montantPaye;
  final String? statutPaiement;

  const DocumentTotalsFooter({
    super.key,
    required this.totalHtBrut,
    required this.totalTva,
    required this.totalHt,
    required this.totalTtc,
    required this.remiseGlobalePct,
    this.tvaGlobalePct = 18.0,
    this.appliquerTva = false,
    this.onRemiseChanged,
    this.onAppliquerTvaChanged,
    this.onTvaChanged,
    this.montantPaye,
    this.statutPaiement,
  });

  @override
  State<DocumentTotalsFooter> createState() => _DocumentTotalsFooterState();
}

class _DocumentTotalsFooterState extends State<DocumentTotalsFooter> {
  late TextEditingController _remiseCtrl;
  late TextEditingController _tvaCtrl;

  @override
  void initState() {
    super.initState();
    _remiseCtrl = TextEditingController(
      text: widget.remiseGlobalePct > 0
          ? widget.remiseGlobalePct.toStringAsFixed(1)
          : '',
    );
    _tvaCtrl = TextEditingController(
      text: _pctTexte(widget.tvaGlobalePct),
    );
  }

  @override
  void didUpdateWidget(DocumentTotalsFooter old) {
    super.didUpdateWidget(old);
    if (old.remiseGlobalePct != widget.remiseGlobalePct) {
      final parsed = double.tryParse(_remiseCtrl.text) ?? 0;
      if (parsed != widget.remiseGlobalePct) {
        _remiseCtrl.text = widget.remiseGlobalePct > 0
            ? widget.remiseGlobalePct.toStringAsFixed(1)
            : '';
      }
    }
    if (old.tvaGlobalePct != widget.tvaGlobalePct) {
      final parsed = double.tryParse(_tvaCtrl.text) ?? 0;
      if (parsed != widget.tvaGlobalePct) {
        _tvaCtrl.text = _pctTexte(widget.tvaGlobalePct);
      }
    }
  }

  @override
  void dispose() {
    _remiseCtrl.dispose();
    _tvaCtrl.dispose();
    super.dispose();
  }

  static String _pctTexte(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final hasRemise = widget.remiseGlobalePct > 0;
    final isEditing = widget.onRemiseChanged != null;
    final resteAPayer = widget.montantPaye != null
        ? widget.totalTtc - widget.montantPaye!
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sous-total HT ─────────────────────────────────────────────
          _LigneTotaux(
            label: 'Sous-total HT',
            valeur: CurrencyFormatter.format(widget.totalHtBrut),
          ),

          // ── Remise ────────────────────────────────────────────────────
          if (isEditing)
            _RemiseField(
              controller: _remiseCtrl,
              onChanged: (v) =>
                  widget.onRemiseChanged!(double.tryParse(v) ?? 0),
            )
          else if (hasRemise)
            _LigneTotaux(
              label:
                  'Remise (${widget.remiseGlobalePct.toStringAsFixed(1)}%)',
              valeur: CurrencyFormatter.format(
                  widget.totalHtBrut - widget.totalHt),
              isNegative: true,
            ),

          if (hasRemise)
            _LigneTotaux(
              label: 'Total HT après remise',
              valeur: CurrencyFormatter.format(widget.totalHt),
            ),

          // ── Bloc TVA ──────────────────────────────────────────────────
          if (isEditing) ...[
            const SizedBox(height: 4),
            _TvaControl(
              appliquerTva: widget.appliquerTva,
              controller: _tvaCtrl,
              onToggle: widget.onAppliquerTvaChanged,
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) widget.onTvaChanged!(parsed);
              },
            ),
            if (widget.appliquerTva && widget.totalTva > 0)
              _LigneTotaux(
                label:
                    'Montant TVA (${_pctTexte(widget.tvaGlobalePct)}%)',
                valeur: CurrencyFormatter.format(widget.totalTva),
              ),
          ] else if (widget.totalTva > 0) ...[
            _LigneTotaux(
              label: 'TVA (${_pctTexte(widget.tvaGlobalePct)}%)',
              valeur: CurrencyFormatter.format(widget.totalTva),
            ),
          ],

          // ── Séparateur + TOTAL TTC ────────────────────────────────────
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          _LigneTotaux(
            label: widget.totalTva > 0 ? 'TOTAL TTC' : 'MONTANT TOTAL',
            valeur: CurrencyFormatter.format(widget.totalTtc),
            isBold: true,
            isTotal: true,
          ),

          // ── Paiements ─────────────────────────────────────────────────
          if (widget.montantPaye != null) ...[
            const SizedBox(height: 6),
            _LigneTotaux(
              label: 'Payé',
              valeur: CurrencyFormatter.format(widget.montantPaye!),
              color: AppColors.success,
            ),
            _LigneTotaux(
              label: 'Reste à payer',
              valeur: CurrencyFormatter.format(resteAPayer!),
              isBold: resteAPayer > 0,
              color: resteAPayer > 0 ? AppColors.danger : AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────────────────────

class _LigneTotaux extends StatelessWidget {
  final String label;
  final String valeur;
  final bool isBold;
  final bool isTotal;
  final bool isNegative;
  final Color? color;

  const _LigneTotaux({
    required this.label,
    required this.valeur,
    this.isBold = false,
    this.isTotal = false,
    this.isNegative = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (isNegative
            ? AppColors.danger
            : isBold
                ? AppColors.textPrimary
                : AppColors.textSecondary);

    final style = isTotal
        ? AppTextStyles.h3.copyWith(color: effectiveColor)
        : isBold
            ? AppTextStyles.bodyBold.copyWith(color: effectiveColor)
            : AppTextStyles.body.copyWith(color: effectiveColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(valeur, style: style),
        ],
      ),
    );
  }
}

class _RemiseField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _RemiseField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text('Remise globale (%)',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                suffixText: '%',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne "Appliquer une TVA" avec case à cocher et champ de taux.
class _TvaControl extends StatelessWidget {
  final bool appliquerTva;
  final TextEditingController controller;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String> onChanged;

  const _TvaControl({
    required this.appliquerTva,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: appliquerTva,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged:
                  onToggle != null ? (v) => onToggle!(v ?? false) : null,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Appliquer une TVA',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              enabled: appliquerTva,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'TVA',
                suffixText: '%',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
