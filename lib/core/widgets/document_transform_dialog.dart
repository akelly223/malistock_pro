import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import '../../core/services/document_transformation_service.dart';
import 'app_button.dart';

/// Résultat d'une transformation : type cible + quantités éventuellement
/// réduites pour un bon de livraison partiel.
class TransformationResult {
  final DocumentType cibleType;
  final Map<int, double>? quantitesParLigneId;

  const TransformationResult({
    required this.cibleType,
    this.quantitesParLigneId,
  });
}

/// Affiche la boîte de dialogue de confirmation de transformation.
///
/// Retourne [TransformationResult] si l'utilisateur confirme, null sinon.
Future<TransformationResult?> showDocumentTransformDialog({
  required BuildContext context,
  required DocumentEntity document,
  DocumentType? cibleForcee,
}) {
  return showDialog<TransformationResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TransformDialog(
      document: document,
      cibleForcee: cibleForcee,
    ),
  );
}

class _TransformDialog extends StatefulWidget {
  final DocumentEntity document;
  final DocumentType? cibleForcee;

  const _TransformDialog({
    required this.document,
    this.cibleForcee,
  });

  @override
  State<_TransformDialog> createState() => _TransformDialogState();
}

class _TransformDialogState extends State<_TransformDialog> {
  late DocumentType _cibleSelectionnee;
  bool _livraison_partielle = false;
  late Map<int, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final rules = const DocumentTransformationService();
    final possibles = rules.transformationsPossibles(widget.document);
    _cibleSelectionnee = widget.cibleForcee ??
        (possibles.isNotEmpty ? possibles.first : DocumentType.facture);

    _controllers = {
      for (final l in widget.document.lignes)
        l.id: TextEditingController(
            text: l.quantite.toStringAsFixed(0).replaceAll(RegExp(r'\.0$'), '')),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  bool get _peutEtrePartiel =>
      _cibleSelectionnee == DocumentType.bonLivraison &&
      widget.document.type == DocumentType.bonCommande;

  Map<int, double>? get _quantitesSaisies {
    if (!_livraison_partielle) return null;
    return {
      for (final l in widget.document.lignes)
        l.id: double.tryParse(_controllers[l.id]?.text ?? '') ?? l.quantite,
    };
  }

  void _confirmer() {
    Navigator.of(context).pop(TransformationResult(
      cibleType: _cibleSelectionnee,
      quantitesParLigneId: _quantitesSaisies,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rules = const DocumentTransformationService();
    final possibles = widget.cibleForcee != null
        ? [widget.cibleForcee!]
        : rules.transformationsPossibles(widget.document);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Text('Transformer le document'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document source : ${widget.document.type.libelle} ${widget.document.numero}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),

            // ── Sélection de la cible ─────────────────────────────────
            if (possibles.length > 1) ...[
              Text('Créer un(e) :', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              ...possibles.map((type) => RadioListTile<DocumentType>(
                    value: type,
                    groupValue: _cibleSelectionnee,
                    title: Text(type.libelle),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _cibleSelectionnee = v;
                          _livraison_partielle = false;
                        });
                      }
                    },
                  )),
            ] else
              Text(
                'Créer un(e) : ${_cibleSelectionnee.libelle}',
                style: AppTextStyles.bodyBold,
              ),

            // ── Livraison partielle (BL depuis BC uniquement) ─────────
            if (_peutEtrePartiel) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _livraison_partielle,
                onChanged: (v) =>
                    setState(() => _livraison_partielle = v),
                title: const Text('Livraison partielle'),
                subtitle: const Text(
                    'Modifier les quantités à livrer ligne par ligne'),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_livraison_partielle) ...[
                const SizedBox(height: 12),
                ...widget.document.lignes.map((ligne) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ligne.articleNom,
                                    style: AppTextStyles.bodyBold),
                                Text(
                                  'Commandé : ${ligne.quantite.toStringAsFixed(0)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _controllers[ligne.id],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'À livrer',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        AppButton(
          label: 'Transformer',
          icon: Icons.swap_horiz_rounded,
          onPressed: _confirmer,
        ),
      ],
    );
  }
}
