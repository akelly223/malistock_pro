import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Retour explicite de [demanderMotDePasse] quand l'utilisateur choisit
/// de ne PAS protéger le fichier (à distinguer de `null` = annulé).
const String motDePasseAucun = '';

/// Dialogue de saisie d'un mot de passe optionnel.
///
/// - En mode [creation] : propose une case à cocher "Protéger par un
///   mot de passe" et affiche l'avertissement de non-récupération.
/// - Sinon (ouverture d'un fichier déjà protégé) : demande directement
///   le mot de passe, avec un message d'erreur si [erreurPrecedente].
///
/// Retourne `null` si annulé, [motDePasseAucun] si explicitement aucun
/// mot de passe choisi, ou le mot de passe saisi sinon.
Future<String?> demanderMotDePasse(
  BuildContext context, {
  required bool creation,
  bool erreurPrecedente = false,
  String? titre,
}) {
  final controller = TextEditingController();
  var proteger = !creation;

  return showDialog<String?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(titre ??
            (creation
                ? 'Protéger ce dossier par un mot de passe ?'
                : 'Mot de passe requis')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (erreurPrecedente) ...[
                const Text(
                  'Mot de passe incorrect. Réessayez.',
                  style: TextStyle(color: AppColors.danger),
                ),
                const SizedBox(height: 12),
              ],
              if (creation)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: proteger,
                  onChanged: (v) => setState(() => proteger = v ?? false),
                  title: const Text('Protéger par un mot de passe'),
                ),
              if (!creation || proteger) ...[
                const SizedBox(height: 4),
                AppTextField(
                  label: 'Mot de passe',
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                ),
              ],
              if (creation && proteger) ...[
                const SizedBox(height: 12),
                const Text(
                  'Attention : si vous oubliez ce mot de passe, vos '
                  'données seront définitivement inaccessibles. Aucune '
                  'récupération n\'est possible, y compris depuis une '
                  'sauvegarde.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: creation ? 'Continuer' : 'Valider',
            onPressed: () {
              if (creation && !proteger) {
                Navigator.of(ctx).pop(motDePasseAucun);
                return;
              }
              Navigator.of(ctx).pop(controller.text);
            },
          ),
        ],
      ),
    ),
  );
}
