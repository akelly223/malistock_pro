import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers/licence_provider.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/constants/app_identity.dart';
import '../../core/licence/licence_service.dart';

/// Statut de l'essai / de la licence, code PC à envoyer à l'éditeur et
/// saisie de la clé reçue.
class LicenceScreen extends ConsumerStatefulWidget {
  const LicenceScreen({super.key});

  @override
  ConsumerState<LicenceScreen> createState() => _LicenceScreenState();
}

class _LicenceScreenState extends ConsumerState<LicenceScreen> {
  final _cleController = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _cleController.dispose();
    super.dispose();
  }

  Future<void> _activer() async {
    if (_cleController.text.trim().isEmpty) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final ok =
        await ref.read(licenceProvider.notifier).activer(_cleController.text);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _erreur = ok
          ? null
          : 'Clé refusée. Vérifiez qu\'elle a été copiée en entier et '
              'qu\'elle a bien été générée pour le code PC affiché ci-dessus.';
    });
    if (ok) {
      _cleController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Licence activée. Merci pour votre confiance !'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(licenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Licence')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CarteStatut(etat: etat),
                if (etat.statut != StatutLicence.licencie) ...[
                  const SizedBox(height: 24),
                  const Text('Comment obtenir votre licence', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  const _Etape(
                    numero: 1,
                    texte: 'Envoyez votre code PC par WhatsApp au '
                        '${AppIdentity.whatsapp} :',
                  ),
                  const SizedBox(height: 8),
                  _CodePc(code: etat.codePc),
                  const SizedBox(height: 16),
                  const _Etape(
                    numero: 2,
                    texte: 'Effectuez le paiement (Orange Money / Moov Money). '
                        'Vous recevrez votre clé de licence à vie.',
                  ),
                  const SizedBox(height: 16),
                  const _Etape(
                    numero: 3,
                    texte: 'Collez la clé reçue ci-dessous puis cliquez sur '
                        '« Activer ».',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cleController,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Clé de licence',
                      border: const OutlineInputBorder(),
                      errorText: _erreur,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _enCours ? null : _activer,
                      icon: _enCours
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('Activer'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteStatut extends StatelessWidget {
  final EtatLicence etat;
  const _CarteStatut({required this.etat});

  @override
  Widget build(BuildContext context) {
    final jours = etat.joursRestants;
    final (IconData icone, Color couleur, Color fond, String titre, String detail) =
        switch (etat.statut) {
      StatutLicence.licencie => (
          Icons.verified_rounded,
          AppColors.success,
          AppColors.successLight,
          'Licence activée',
          'Votre licence à vie est active sur cet ordinateur.',
        ),
      StatutLicence.essai => (
          Icons.hourglass_top_rounded,
          etat.afficherRappel ? AppColors.warning : AppColors.primary,
          etat.afficherRappel ? AppColors.warningLight : AppColors.primaryLight,
          'Période d\'essai : $jours jour${jours > 1 ? 's' : ''} '
              'restant${jours > 1 ? 's' : ''}',
          etat.finEssai == null
              ? 'Toutes les fonctionnalités sont disponibles.'
              : 'Toutes les fonctionnalités sont disponibles jusqu\'au '
                  '${DateFormat('dd/MM/yyyy').format(etat.finEssai!.toLocal())}.',
        ),
      StatutLicence.expire => (
          Icons.lock_clock_rounded,
          AppColors.danger,
          AppColors.dangerLight,
          'Période d\'essai terminée',
          'Vos données restent consultables : vous pouvez les voir, les '
              'imprimer, les exporter et les sauvegarder. Activez votre '
              'licence pour enregistrer de nouvelles opérations.',
        ),
      StatutLicence.horlogeIncoherente => (
          Icons.schedule_rounded,
          AppColors.danger,
          AppColors.dangerLight,
          'Date de l\'ordinateur incorrecte',
          'La date de cet ordinateur est antérieure à la dernière '
              'utilisation du logiciel. Corrigez la date et l\'heure de '
              'Windows puis relancez le logiciel. En attendant, vos données '
              'restent consultables.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppTextStyles.h3.copyWith(color: couleur)),
                const SizedBox(height: 6),
                Text(detail, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final int numero;
  final String texte;
  const _Etape({required this.numero, required this.texte});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text('$numero',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: AppTextStyles.body)),
        ],
      );
}

class _CodePc extends StatelessWidget {
  final String code;
  const _CodePc({required this.code});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                code,
                style: AppTextStyles.h3.copyWith(
                    fontFamily: 'monospace', letterSpacing: 1.5),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code PC copié')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copier'),
            ),
          ],
        ),
      );
}
