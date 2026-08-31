import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

// ── Hub Ventes ────────────────────────────────────────────────────────────────

class VentesHubScreen extends StatelessWidget {
  const VentesHubScreen({super.key});

  static const _cartes = [
    _CarteHub(
      label: 'Nouvelle vente',
      description: 'Enregistrer une vente immédiate',
      icon: Icons.add_shopping_cart_rounded,
      couleur: Color(0xFF1E6F46),
      route: '/factures-v2/new',
    ),
    _CarteHub(
      label: 'Factures',
      description: 'Consulter et gérer toutes les factures',
      icon: Icons.receipt_long_rounded,
      couleur: Color(0xFF2196F3),
      route: '/factures-v2',
    ),
    _CarteHub(
      label: 'Proformas',
      description: 'Devis et propositions commerciales',
      icon: Icons.description_outlined,
      couleur: Color(0xFF00897B),
      route: '/proformas',
    ),
    _CarteHub(
      label: 'Devis',
      description: 'Estimations et offres clients',
      icon: Icons.request_quote_outlined,
      couleur: Color(0xFFFF9800),
      route: '/quotes',
    ),
    _CarteHub(
      label: 'Historique',
      description: 'Toutes les anciennes ventes',
      icon: Icons.history_rounded,
      couleur: Color(0xFF9C27B0),
      route: '/invoices',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ventes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Module Ventes', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text('Choisissez une action pour commencer.', style: AppTextStyles.caption),
            const SizedBox(height: 28),
            _GrilleCartes(cartes: _cartes),
          ],
        ),
      ),
    );
  }
}

// ── Hub Achats ────────────────────────────────────────────────────────────────

class AchatsHubScreen extends StatelessWidget {
  const AchatsHubScreen({super.key});

  static const _cartes = [
    _CarteHub(
      label: 'Nouvel achat',
      description: 'Enregistrer un achat fournisseur',
      icon: Icons.add_business_rounded,
      couleur: Color(0xFF1E6F46),
      route: '/purchases/new',
    ),
    _CarteHub(
      label: 'Historique',
      description: 'Tous les achats passés',
      icon: Icons.shopping_cart_rounded,
      couleur: Color(0xFF2196F3),
      route: '/purchases',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Achats')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Module Achats', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text('Gérez vos achats fournisseurs.', style: AppTextStyles.caption),
            const SizedBox(height: 28),
            _GrilleCartes(cartes: _cartes),
          ],
        ),
      ),
    );
  }
}

// ── Hub Stock ─────────────────────────────────────────────────────────────────

class StockHubScreen extends StatelessWidget {
  const StockHubScreen({super.key});

  static const _cartes = [
    _CarteHub(
      label: 'Mouvements',
      description: 'Entrées et sorties de stock',
      icon: Icons.swap_horiz_rounded,
      couleur: Color(0xFF1E6F46),
      route: '/stock',
    ),
    _CarteHub(
      label: 'Alertes',
      description: 'Articles en rupture ou en alerte',
      icon: Icons.notification_important_rounded,
      couleur: Color(0xFFC23B33),
      route: '/alerts',
    ),
    _CarteHub(
      label: 'Magasins',
      description: 'Gérer vos dépôts et entrepôts',
      icon: Icons.store_rounded,
      couleur: Color(0xFF2196F3),
      route: '/stores',
    ),
    _CarteHub(
      label: 'Inventaire',
      description: 'Comptage physique et mise à jour du stock',
      icon: Icons.playlist_add_check_rounded,
      couleur: Color(0xFF7B5EA7),
      route: '/inventory',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Module Stock', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text('Suivez et gérez votre inventaire.', style: AppTextStyles.caption),
            const SizedBox(height: 28),
            _GrilleCartes(cartes: _cartes),
          ],
        ),
      ),
    );
  }
}

// ── Grille générique — sans hauteur fixe pour éviter les overflows ─────────────

class _GrilleCartes extends StatelessWidget {
  final List<_CarteHub> cartes;
  const _GrilleCartes({required this.cartes});

  @override
  Widget build(BuildContext context) {
    // On utilise LayoutBuilder pour connaître la largeur disponible.
    return LayoutBuilder(builder: (context, constraints) {
      final disponible = constraints.maxWidth;
      final cols = disponible > 900 ? 4 : disponible > 600 ? 3 : 2;
      final gap = 16.0;
      final cardWidth = ((disponible - gap * (cols - 1)) / cols).clamp(140.0, 300.0);

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cartes.map((carte) {
          return SizedBox(
            width: cardWidth,
            child: _TuileCarte(carte: carte),
          );
        }).toList(),
      );
    });
  }
}

// ── Carte individuelle — hauteur auto, jamais overflow ────────────────────────

class _TuileCarte extends StatelessWidget {
  final _CarteHub carte;
  const _TuileCarte({required this.carte});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // push() préserve la pile de navigation → bouton ← automatique
        onTap: () => context.push(carte.route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            // min = la carte s'adapte au contenu, pas de débordement
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: carte.couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(carte.icon, color: carte.couleur, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                carte.label,
                style: AppTextStyles.bodyBold.copyWith(fontSize: 13.5),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                carte.description,
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modèle ────────────────────────────────────────────────────────────────────

class _CarteHub {
  final String label;
  final String description;
  final IconData icon;
  final Color couleur;
  final String route;

  const _CarteHub({
    required this.label,
    required this.description,
    required this.icon,
    required this.couleur,
    required this.route,
  });
}
