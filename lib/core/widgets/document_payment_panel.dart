import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_input.dart';
import 'app_button.dart';

/// Panneau de paiements d'un document : liste des règlements existants
/// et formulaire d'ajout d'un nouveau paiement.
///
/// [onAjouterPaiement] est appelé uniquement si le document n'est pas
/// entièrement soldé et que le document est dans un état qui accepte
/// les paiements (contrôle laissé à l'écran parent via [peutPayer]).
class DocumentPaymentPanel extends StatefulWidget {
  final DocumentEntity document;
  final bool peutPayer;
  final bool isLoading;
  final void Function(DocumentPaiementInput)? onAjouterPaiement;

  const DocumentPaymentPanel({
    super.key,
    required this.document,
    this.peutPayer = false,
    this.isLoading = false,
    this.onAjouterPaiement,
  });

  @override
  State<DocumentPaymentPanel> createState() => _DocumentPaymentPanelState();
}

/// Modes de paiement disponibles pour un document commercial V2, partagés
/// entre le panneau de paiement (règlement a posteriori) et la vente
/// comptoir (paiement saisi à la création).
const documentPaymentModes = [
  ('especes', 'Espèces'),
  ('cheque', 'Chèque'),
  ('virement', 'Virement'),
  ('mobile_money', 'Mobile Money'),
  ('carte', 'Carte bancaire'),
  ('avoir', 'Avoir'),
];

class _DocumentPaymentPanelState extends State<DocumentPaymentPanel> {
  static const _modes = documentPaymentModes;

  final _montantCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _datePaiement = DateTime.now();
  String _modePaiement = 'especes';
  bool _showForm = false;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  DocumentEntity get _doc => widget.document;

  double get _resteAPayer => _doc.resteAPayer;

  void _ouvrirFormulaire() {
    _montantCtrl.text =
        _resteAPayer > 0 ? _resteAPayer.toStringAsFixed(0) : '';
    _referenceCtrl.clear();
    _datePaiement = DateTime.now();
    _modePaiement = 'especes';
    setState(() => _showForm = true);
  }

  void _annulerFormulaire() => setState(() => _showForm = false);

  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePaiement,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _datePaiement = picked);
  }

  void _soumettre() {
    if (!_formKey.currentState!.validate()) return;
    final montant = double.tryParse(_montantCtrl.text) ?? 0;
    widget.onAjouterPaiement?.call(DocumentPaiementInput(
      montant: montant,
      datePaiement: _datePaiement,
      modePaiement: _modePaiement,
      reference:
          _referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : null,
    ));
    setState(() => _showForm = false);
  }

  @override
  Widget build(BuildContext context) {
    final paiements = _doc.paiements;
    final totalPaye = _doc.montantPaye;
    final resteAPayer = _resteAPayer;
    final estSolde = _doc.estPaye;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Text('Paiements', style: AppTextStyles.h3),
                const Spacer(),
                if (widget.peutPayer && !estSolde && !_showForm)
                  AppButton(
                    label: 'Ajouter un règlement',
                    icon: Icons.add_rounded,
                    isOutlined: true,
                    onPressed:
                        widget.isLoading ? null : _ouvrirFormulaire,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // ── Résumé montants ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                _SommePuce(
                  label: 'Total TTC',
                  montant: _doc.totalTtc,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 24),
                _SommePuce(
                  label: 'Payé',
                  montant: totalPaye,
                  color: AppColors.success,
                ),
                const SizedBox(width: 24),
                _SommePuce(
                  label: estSolde ? 'Soldé' : 'Reste à payer',
                  montant: resteAPayer,
                  color:
                      estSolde ? AppColors.success : AppColors.danger,
                  bold: true,
                ),
              ],
            ),
          ),

          // ── Liste des paiements ────────────────────────────────────────
          if (paiements.isEmpty && !_showForm)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text('Aucun paiement enregistré',
                  style: AppTextStyles.caption),
            )
          else ...[
            if (paiements.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paiements.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) =>
                    _PaiementLigne(paiement: paiements[i]),
              ),
          ],

          // ── Formulaire d'ajout ─────────────────────────────────────────
          if (_showForm) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouveau règlement', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Montant
                        Expanded(
                          child: TextFormField(
                            controller: _montantCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Montant *',
                              prefixText: 'FCFA ',
                              isDense: true,
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) {
                                return 'Montant invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Mode de paiement
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _modePaiement,
                            decoration: const InputDecoration(
                              labelText: 'Mode *',
                              isDense: true,
                            ),
                            items: _modes
                                .map((m) => DropdownMenuItem(
                                      value: m.$1,
                                      child: Text(m.$2),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _modePaiement = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Date
                        SizedBox(
                          width: 160,
                          child: InkWell(
                            onTap: _choisirDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date *',
                                isDense: true,
                                suffixIcon: Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18),
                              ),
                              child: Text(
                                DateFormatter.formatDate(_datePaiement),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Référence
                    TextFormField(
                      controller: _referenceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Référence (optionnel)',
                        hintText: 'N° chèque, reçu, etc.',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _annulerFormulaire,
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                        AppButton(
                          label: 'Enregistrer le paiement',
                          icon: Icons.check_rounded,
                          isLoading: widget.isLoading,
                          onPressed: widget.isLoading ? null : _soumettre,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaiementLigne extends StatelessWidget {
  final DocumentPaiementEntity paiement;
  const _PaiementLigne({required this.paiement});

  static String _libelleMode(String mode) => switch (mode) {
        'especes' => 'Espèces',
        'cheque' => 'Chèque',
        'virement' => 'Virement',
        'mobile_money' => 'Mobile Money',
        'carte' => 'Carte bancaire',
        'avoir' => 'Avoir',
        _ => mode,
      };

  static IconData _iconeMode(String mode) => switch (mode) {
        'especes' => Icons.payments_outlined,
        'cheque' => Icons.receipt_outlined,
        'virement' => Icons.account_balance_outlined,
        'mobile_money' => Icons.phone_android_outlined,
        'carte' => Icons.credit_card_outlined,
        'avoir' => Icons.undo_outlined,
        _ => Icons.attach_money_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(_iconeMode(paiement.modePaiement),
              size: 20, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_libelleMode(paiement.modePaiement),
                    style: AppTextStyles.body),
                if (paiement.reference != null)
                  Text('Réf. ${paiement.reference!}',
                      style: AppTextStyles.caption),
                if (paiement.createdByNom != null)
                  Text('Par ${paiement.createdByNom!}',
                      style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(paiement.montant),
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.success),
              ),
              Text(
                DateFormatter.formatDate(paiement.datePaiement),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, size: 20),
            tooltip: 'Voir le reçu',
            onPressed: () => context.push('/receipts/v2/${paiement.id}'),
          ),
        ],
      ),
    );
  }
}

class _SommePuce extends StatelessWidget {
  final String label;
  final double montant;
  final Color color;
  final bool bold;

  const _SommePuce({
    required this.label,
    required this.montant,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(montant),
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
