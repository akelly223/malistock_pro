import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../domain/entities/client.dart';
import '../../domain/exceptions/client_doublon_exception.dart';
import 'providers/client_provider.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final int? clientId;

  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _adresseController = TextEditingController();
  final _nifController = TextEditingController();
  final _nomFocusNode = FocusNode();
  final _telephoneFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isInitialised = false;

  /// Client détecté comme doublon potentiel lors de la vérification
  /// en temps réel (au moment où le commerçant quitte un des deux
  /// champs nom/téléphone). N'empêche pas la saisie : seule la
  /// sauvegarde reste réellement bloquante, via le repository.
  ClientEntity? _doublonDetecte;

  bool get _estEdition => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _nomFocusNode.addListener(_onFocusChange);
    _telephoneFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _nomFocusNode.removeListener(_onFocusChange);
    _telephoneFocusNode.removeListener(_onFocusChange);
    _nomFocusNode.dispose();
    _telephoneFocusNode.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _nifController.dispose();
    super.dispose();
  }

  /// Déclenche la vérification de doublon quand l'un des deux champs
  /// concernés (nom ou téléphone) PERD le focus, c'est-à-dire quand
  /// le commerçant vient de le quitter — pas pendant qu'il tape.
  void _onFocusChange() {
    final aPerduLeFocus =
        !_nomFocusNode.hasFocus && !_telephoneFocusNode.hasFocus;
    if (aPerduLeFocus) {
      _verifierDoublonEnTempsReel();
    }
  }

  Future<void> _verifierDoublonEnTempsReel() async {
    final nom = _nomController.text.trim();
    final telephone = _telephoneController.text.trim();
    if (nom.isEmpty || telephone.isEmpty) {
      if (_doublonDetecte != null) setState(() => _doublonDetecte = null);
      return;
    }

    final repo = ref.read(clientRepositoryProvider);
    final doublon = await repo.verifierDoublon(
      nom: nom,
      telephone: telephone,
      excluClientId: widget.clientId,
    );
    if (mounted) setState(() => _doublonDetecte = doublon);
  }

  Future<void> _chargerClientExistant() async {
    if (widget.clientId == null || _isInitialised) return;
    final repo = ref.read(clientRepositoryProvider);
    final client = await repo.getClientById(widget.clientId!);
    if (client != null) {
      setState(() {
        _nomController.text = client.nom;
        _telephoneController.text = client.telephone ?? '';
        _adresseController.text = client.adresse ?? '';
        _nifController.text = client.nif ?? '';
        _isInitialised = true;
      });
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = ref.read(clientRepositoryProvider);

    try {
      if (_estEdition) {
        final existant = await repo.getClientById(widget.clientId!);
        if (existant != null) {
          await repo.updateClient(existant.copyWithEdit(
            nom: _nomController.text.trim(),
            telephone: _telephoneController.text.trim(),
            adresse: _adresseController.text.trim(),
            nif: _nifController.text.trim(),
          ));
        }
      } else {
        await repo.createClient(
          nom: _nomController.text.trim(),
          telephone: _telephoneController.text.trim().isEmpty
              ? null
              : _telephoneController.text.trim(),
          adresse: _adresseController.text.trim().isEmpty
              ? null
              : _adresseController.text.trim(),
          nif: _nifController.text.trim().isEmpty
              ? null
              : _nifController.text.trim(),
        );
      }
      ref.invalidate(filteredClientsProvider);
      if (mounted) context.pop();
    } on ClientDoublonException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Voir la fiche',
              onPressed: () =>
                  context.push('/clients/${e.clientExistantId}'),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estEdition) _chargerClientExistant();

    return Scaffold(
      appBar: AppBar(
        title: Text(_estEdition ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Nom complet',
                    controller: _nomController,
                    focusNode: _nomFocusNode,
                    hint: 'Ex: Aminata Coulibaly',
                    autofocus: true,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Téléphone',
                    controller: _telephoneController,
                    focusNode: _telephoneFocusNode,
                    hint: 'Ex: 76 12 34 56',
                    keyboardType: TextInputType.phone,
                  ),
                  if (_doublonDetecte != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Un client "${_doublonDetecte!.nom}" existe déjà avec ce téléphone.',
                                  style: AppTextStyles.body
                                      .copyWith(fontSize: 13.5),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => context
                                      .push('/clients/${_doublonDetecte!.id}'),
                                  child: const Text(
                                    'Voir sa fiche →',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Adresse',
                    controller: _adresseController,
                    hint: 'Ex: Quartier Hippodrome, Bamako',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'NIF (optionnel)',
                    controller: _nifController,
                    hint: 'Numéro d\'identification fiscale',
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: _estEdition ? 'Enregistrer' : 'Créer le client',
                    icon: Icons.check_circle_outline,
                    isLoading: _isLoading,
                    onPressed: _enregistrer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
