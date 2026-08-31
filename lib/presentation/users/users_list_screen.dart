import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/constants/db_constants.dart';
import '../../core/permissions/permissions.dart';
import '../../domain/entities/user.dart';
import 'providers/user_provider.dart';

/// Écran de gestion des comptes utilisateurs (admin et employés).
/// La route et l'entrée de menu sont déjà protégées en amont ; l'écran
/// revérifie quand même le rôle lui-même (défense en profondeur).
class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  Future<void> _creerUtilisateur(BuildContext context, WidgetRef ref) async {
    final nomController = TextEditingController();
    final loginController = TextEditingController();
    final motDePasseController = TextEditingController();
    String role = DbConstants.roleEmploye;
    String? erreur;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nouveau compte utilisateur'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nom complet',
                  controller: nomController,
                  hint: 'Ex: Fatoumata Diarra',
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Identifiant de connexion',
                  controller: loginController,
                  hint: 'Ex: fatoumata',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Mot de passe',
                  controller: motDePasseController,
                  obscureText: true,
                  hint: 'Au moins 4 caractères',
                ),
                const SizedBox(height: 14),
                const Text('Rôle', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: DbConstants.roleEmploye, label: Text('Employé')),
                    ButtonSegment(
                        value: DbConstants.roleAdmin,
                        label: Text('Administrateur')),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) =>
                      setStateDialog(() => role = s.first),
                ),
                if (erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(erreur!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            AppButton(
              label: 'Créer le compte',
              onPressed: () async {
                if (nomController.text.trim().isEmpty ||
                    loginController.text.trim().isEmpty ||
                    motDePasseController.text.length < 4) {
                  setStateDialog(() => erreur =
                      'Remplissez tous les champs (mot de passe : 4 caractères minimum).');
                  return;
                }
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirme != true) return;

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.createUser(
        nom: nomController.text.trim(),
        login: loginController.text.trim(),
        motDePasse: motDePasseController.text,
        role: role,
      );
      ref.invalidate(usersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé avec succès.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _modifierUtilisateur(
      BuildContext context, WidgetRef ref, UserEntity user) async {
    final nomController = TextEditingController(text: user.nom);
    final loginController = TextEditingController(text: user.login);
    String role = user.role;
    String? erreur;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Modifier le compte'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nom complet',
                  controller: nomController,
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Identifiant de connexion',
                  controller: loginController,
                ),
                const SizedBox(height: 14),
                const Text('Rôle', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: DbConstants.roleEmploye, label: Text('Employé')),
                    ButtonSegment(
                        value: DbConstants.roleAdmin,
                        label: Text('Administrateur')),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) =>
                      setStateDialog(() => role = s.first),
                ),
                if (erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(erreur!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            AppButton(
              label: 'Enregistrer',
              onPressed: () {
                if (nomController.text.trim().isEmpty ||
                    loginController.text.trim().isEmpty) {
                  setStateDialog(
                      () => erreur = 'Remplissez tous les champs.');
                  return;
                }
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirme != true) return;

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateUser(
        userId: user.id,
        nom: nomController.text.trim(),
        login: loginController.text.trim(),
        role: role,
      );
      ref.invalidate(usersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte modifié avec succès.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _reinitialiserMotDePasse(
      BuildContext context, WidgetRef ref, UserEntity user) async {
    final motDePasseController = TextEditingController();
    String? erreur;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Réinitialiser le mot de passe de ${user.nom}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nouveau mot de passe',
                  controller: motDePasseController,
                  obscureText: true,
                  hint: 'Au moins 4 caractères',
                  autofocus: true,
                ),
                if (erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(erreur!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            AppButton(
              label: 'Réinitialiser',
              onPressed: () {
                if (motDePasseController.text.length < 4) {
                  setStateDialog(() => erreur =
                      'Le mot de passe doit contenir au moins 4 caractères.');
                  return;
                }
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirme != true) return;

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.resetPassword(
        userId: user.id,
        nouveauMotDePasse: motDePasseController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe réinitialisé.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _desactiverUtilisateur(
      BuildContext context, WidgetRef ref, UserEntity user) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver ce compte ?'),
        content: Text(
            '${user.nom} ne pourra plus se connecter à l\'application. Cette action peut être annulée plus tard si besoin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Désactiver',
            isDanger: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirme == true) {
      final repo = ref.read(authRepositoryProvider);
      await repo.deactivateUser(user.id);
      ref.invalidate(usersListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateurConnecte = ref.watch(sessionProvider);
    if (!Permissions.peutGererUtilisateurs(utilisateurConnecte)) {
      return const AccessDeniedView(titre: 'Utilisateurs');
    }

    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvel utilisateur',
              icon: Icons.person_add_alt_rounded,
              onPressed: () => _creerUtilisateur(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return const EmptyState(
                icon: Icons.people_outline,
                message: 'Aucun utilisateur trouvé.',
              );
            }
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                final estSoiMeme = user.id == utilisateurConnecte?.id;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: user.actif ? AppColors.surface : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: user.estAdmin
                            ? AppColors.primaryLight
                            : AppColors.secondaryLight,
                        child: Text(
                          user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: user.estAdmin
                                ? AppColors.primary
                                : AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(user.nom, style: AppTextStyles.bodyBold),
                                if (estSoiMeme) ...[
                                  const SizedBox(width: 6),
                                  Text('(vous)', style: AppTextStyles.caption),
                                ],
                              ],
                            ),
                            Text(
                              '@${user.login} · ${user.estAdmin ? 'Administrateur' : 'Employé'}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      if (!user.actif)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Désactivé',
                              style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Modifier',
                        onPressed: () =>
                            _modifierUtilisateur(context, ref, user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_reset_outlined),
                        tooltip: 'Réinitialiser le mot de passe',
                        onPressed: () =>
                            _reinitialiserMotDePasse(context, ref, user),
                      ),
                      if (user.actif && !estSoiMeme)
                        IconButton(
                          icon: const Icon(Icons.person_off_outlined,
                              color: AppColors.danger),
                          tooltip: 'Désactiver ce compte',
                          onPressed: () =>
                              _desactiverUtilisateur(context, ref, user),
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}
