import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../domain/entities/remise_globale.dart';

/// Champ de saisie de remise globale avec sélecteur de mode FCFA / %.
///
/// CORRECTIF FOCUS : ce widget gère son [TextEditingController] dans
/// son propre State, créé une seule fois dans [initState] et jamais
/// recréé pendant la frappe. C'est la cause du bug de perte de focus
/// historique : un ancien code instanciait `TextEditingController(...)`
/// directement dans `build()`, donc à chaque frappe (`setState` ->
/// rebuild -> nouveau controller -> nouveau TextField), Flutter ne
/// reconnaissait plus le champ comme "le même" et lui retirait le
/// focus. Ici, [didUpdateWidget] resynchronise le texte affiché
/// uniquement si la valeur vient changer depuis l'EXTÉRIEUR du widget
/// (par exemple un reset du formulaire), jamais en réaction à la
/// propre frappe de l'utilisateur.
class DiscountInputField extends StatefulWidget {
  final RemiseGlobale remise;
  final void Function(RemiseGlobale) onChanged;

  const DiscountInputField({
    super.key,
    required this.remise,
    required this.onChanged,
  });

  @override
  State<DiscountInputField> createState() => _DiscountInputFieldState();
}

class _DiscountInputFieldState extends State<DiscountInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.remise.valeur == 0
          ? ''
          : widget.remise.valeur.toStringAsFixed(
              widget.remise.type == RemiseType.pourcentage ? 1 : 0),
    );
  }

  @override
  void didUpdateWidget(DiscountInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne resynchronise que si la valeur a changé pour une raison
    // EXTÉRIEURE à la frappe locale (ex: changement de type FCFA/%,
    // ou réinitialisation du formulaire) — jamais à chaque frappe,
    // sinon on retombe dans le bug de focus initial.
    final valeurAffichee = double.tryParse(_controller.text) ?? 0;
    final memeValeur = (valeurAffichee - widget.remise.valeur).abs() < 0.001;
    if (!memeValeur) {
      _controller.text = widget.remise.valeur == 0
          ? ''
          : widget.remise.valeur.toStringAsFixed(
              widget.remise.type == RemiseType.pourcentage ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changerType(RemiseType nouveauType) {
    if (nouveauType == widget.remise.type) return;
    // En changeant de mode, on repart à zéro plutôt que de garder un
    // nombre qui n'aurait plus de sens (ex: "20" en FCFA devenant
    // "20%" accidentellement).
    _controller.clear();
    widget.onChanged(RemiseGlobale(valeur: 0, type: nouveauType));
  }

  void _onTexteChange(String texte) {
    var valeur = double.tryParse(texte) ?? 0;
    // Garde-fou métier : une remise en pourcentage ne peut jamais
    // dépasser 100%.
    if (widget.remise.type == RemiseType.pourcentage && valeur > 100) {
      valeur = 100;
      // Corrige aussi l'affichage pour que l'utilisateur voie
      // immédiatement que la valeur a été plafonnée.
      _controller.value = TextEditingValue(
        text: '100',
        selection: const TextSelection.collapsed(offset: 3),
      );
    }
    widget.onChanged(widget.remise.copyWith(valeur: valeur));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Remise globale',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText:
                      widget.remise.type == RemiseType.pourcentage
                          ? '%'
                          : 'FCFA',
                ),
                onChanged: _onTexteChange,
              ),
            ),
            const SizedBox(width: 10),
            _ModeToggle(
              type: widget.remise.type,
              onChanged: _changerType,
            ),
          ],
        ),
      ],
    );
  }
}

/// Sélecteur FCFA / % compact, à droite du champ de saisie.
class _ModeToggle extends StatelessWidget {
  final RemiseType type;
  final void Function(RemiseType) onChanged;

  const _ModeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'FCFA',
            selected: type == RemiseType.montant,
            onTap: () => onChanged(RemiseType.montant),
            isLeft: true,
          ),
          _ModeButton(
            label: '%',
            selected: type == RemiseType.pourcentage,
            onTap: () => onChanged(RemiseType.pourcentage),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLeft;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(7) : Radius.zero,
        right: !isLeft ? const Radius.circular(7) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(7) : Radius.zero,
            right: !isLeft ? const Radius.circular(7) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
