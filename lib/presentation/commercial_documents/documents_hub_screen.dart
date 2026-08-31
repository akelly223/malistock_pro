import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Hub de navigation vers les différents types de pièces commerciales.
/// Accessible depuis le menu principal "Documents".
class DocumentsHubScreen extends StatelessWidget {
  const DocumentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pièces commerciales', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(
              'Sélectionnez le type de document à consulter ou créer.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 800
                    ? 3
                    : constraints.maxWidth > 520
                        ? 2
                        : 1;
                return _DocumentsGrid(cols: cols);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grille de cartes ──────────────────────────────────────────────────────────

class _DocumentsGrid extends StatelessWidget {
  final int cols;
  const _DocumentsGrid({required this.cols});

  static const _types = [
    _TypeDoc(
      label: 'Proformas',
      description: 'Devis et propositions commerciales',
      icon: Icons.description_outlined,
      couleur: Color(0xFF4CAF50),
      route: '/proformas',
    ),
    _TypeDoc(
      label: 'Bons de commande',
      description: 'Commandes clients confirmées',
      icon: Icons.assignment_outlined,
      couleur: Color(0xFF2196F3),
      route: '/bons-commande',
    ),
    _TypeDoc(
      label: 'Préparations',
      description: 'Préparation des commandes à expédier',
      icon: Icons.inventory_outlined,
      couleur: Color(0xFF9C27B0),
      route: '/preparations-livraison',
    ),
    _TypeDoc(
      label: 'Bons de livraison',
      description: 'Documents de livraison aux clients',
      icon: Icons.local_shipping_outlined,
      couleur: Color(0xFF00BCD4),
      route: '/bons-livraison',
    ),
    _TypeDoc(
      label: 'Bons de retour',
      description: 'Retours de marchandise client',
      icon: Icons.keyboard_return_outlined,
      couleur: Color(0xFFFF9800),
      route: '/bons-retour',
    ),
    _TypeDoc(
      label: 'Avoirs',
      description: 'Crédits et remboursements clients',
      icon: Icons.undo_outlined,
      couleur: Color(0xFFF44336),
      route: '/avoirs',
    ),
    _TypeDoc(
      label: 'Factures',
      description: 'Factures de vente avec TVA',
      icon: Icons.receipt_long_outlined,
      couleur: Color(0xFF1B5E20),
      route: '/factures-v2',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _types.map((type) {
        final itemWidth = (MediaQuery.of(context).size.width -
                    250 - // sidebar
                    56 - // outer padding (28*2)
                    (16 * (cols - 1))) / // gaps
                cols;
        return SizedBox(
          width: itemWidth.clamp(200.0, 440.0),
          child: _CarteDocument(type: type),
        );
      }).toList(),
    );
  }
}

// ── Carte d'un type de document ───────────────────────────────────────────────

class _CarteDocument extends StatelessWidget {
  final _TypeDoc type;
  const _CarteDocument({required this.type});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(type.route),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Icône dans cercle coloré
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: type.couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(type.icon, color: type.couleur, size: 26),
              ),
              const SizedBox(width: 16),
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: AppTextStyles.bodyBold
                            .copyWith(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(type.description,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              // Flèche
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modèle interne ────────────────────────────────────────────────────────────

class _TypeDoc {
  final String label;
  final String description;
  final IconData icon;
  final Color couleur;
  final String route;

  const _TypeDoc({
    required this.label,
    required this.description,
    required this.icon,
    required this.couleur,
    required this.route,
  });
}
