import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/constants/app_identity.dart';
import '../../core/services/demo_data_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _erreur;

  // Champs pour la création du premier compte admin.
  final _nomController = TextEditingController();
  bool _modeCreationAdmin = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _erreur = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final user = await repo.login(
      _loginController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (user == null) {
      setState(() => _erreur = 'Identifiant ou mot de passe incorrect.');
      return;
    }

    ref.read(sessionProvider.notifier).setUser(user);
    if (mounted) context.go('/dashboard');
  }

  Future<void> _creerPremierAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _erreur = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final user = await repo.createUser(
      nom: _nomController.text.trim(),
      login: _loginController.text.trim(),
      motDePasse: _passwordController.text,
      role: 'admin',
    );

    setState(() => _isLoading = false);
    ref.read(sessionProvider.notifier).setUser(user);
    ref.invalidate(hasAdminProvider);

    if (mounted) {
      await _proposerDonneesDemo(user.id);
    }
    if (mounted) context.go('/dashboard');
  }

  /// Propose, une seule fois au premier lancement, de charger un jeu
  /// de données de démonstration (articles, clients, fournisseurs,
  /// factures) pour qu'un commerçant en test puisse explorer
  /// l'application immédiatement sans tout saisir lui-même.
  Future<void> _proposerDonneesDemo(int adminUserId) async {
    final accepte = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Compte créé avec succès'),
        content: const Text(
          'Voulez-vous charger des données de démonstration (quelques '
          'articles, clients, fournisseurs et factures) pour tester '
          'immédiatement le logiciel ?\n\n'
          'Vous pourrez les supprimer plus tard, module par module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non, je saisirai mes données'),
          ),
          AppButton(
            label: 'Charger les données de démo',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (accepte != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await DemoDataService.creerDonneesDemo(ref, userId: adminUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Les données de démonstration n\'ont pas pu être créées : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAdminAsync = ref.watch(hasAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: hasAdminAsync.when(
              data: (hasAdmin) {
                _modeCreationAdmin = !hasAdmin;
                return _buildCard(context);
              },
              loading: () => const CircularProgressIndicator(color: Colors.white),
              error: (e, _) => Text('Erreur: $e',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              _modeCreationAdmin
                  ? 'Bienvenue ! Créons votre compte'
                  : 'Connexion',
              style: AppTextStyles.h1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _modeCreationAdmin
                  ? 'Premier lancement : créez le compte administrateur de votre boutique.'
                  : 'Entrez vos identifiants pour accéder à votre boutique.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (_modeCreationAdmin) ...[
              AppTextField(
                label: 'Votre nom',
                controller: _nomController,
                hint: 'Ex: Issa Traoré',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(
              label: 'Identifiant',
              controller: _loginController,
              hint: 'Ex: admin',
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Identifiant requis' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Mot de passe',
              controller: _passwordController,
              obscureText: true,
              hint: '••••••••',
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Mot de passe requis'
                  : (v.length < 4 ? 'Au moins 4 caractères' : null),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_erreur!,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: _modeCreationAdmin ? 'Créer mon compte' : 'Se connecter',
              icon: _modeCreationAdmin ? Icons.check_circle : Icons.login,
              isLoading: _isLoading,
              onPressed:
                  _modeCreationAdmin ? _creerPremierAdmin : _seConnecter,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Version ${AppIdentity.version}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Développé par ${AppIdentity.editeur}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
