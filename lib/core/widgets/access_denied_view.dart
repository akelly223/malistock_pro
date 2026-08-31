import 'package:flutter/material.dart';

/// Écran de repli affiché quand un utilisateur sans les droits requis
/// atteint quand même un écran réservé (défense en profondeur : le
/// routeur et le menu latéral bloquent déjà l'accès en amont, cet écran
/// protège au cas où ces couches seraient un jour contournées ou
/// modifiées par erreur).
class AccessDeniedView extends StatelessWidget {
  final String? titre;

  const AccessDeniedView({super.key, this.titre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: titre != null ? AppBar(title: Text(titre!)) : null,
      body: const Center(
        child: Text('Vous ne disposez pas des autorisations nécessaires.'),
      ),
    );
  }
}
