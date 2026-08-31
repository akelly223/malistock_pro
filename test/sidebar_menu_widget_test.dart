import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/app/providers/session_provider.dart';
import 'package:malistock_pro/domain/entities/user.dart';
import 'package:malistock_pro/presentation/shell/sidebar_menu.dart';

/// Vérifie ce qu'un compte employé voit réellement dans le menu latéral
/// (widget de production, pas une relecture du code) : exactement les
/// modules listés dans la demande, rien de plus.
void main() {
  final admin = UserEntity(
    id: 1,
    nom: 'Admin',
    login: 'admin',
    role: 'admin',
    actif: true,
    dateCreation: DateTime(2026),
  );

  final employe = UserEntity(
    id: 2,
    nom: 'Employé',
    login: 'employe',
    role: 'employe',
    actif: true,
    dateCreation: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, UserEntity user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => SessionNotifier()..setUser(user)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SidebarMenu(currentRoute: '/dashboard')),
        ),
      ),
    );
  }

  testWidgets('employé ne voit que Tableau de bord, Ventes, Articles, Clients',
      (tester) async {
    await pump(tester, employe);

    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Ventes'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);

    expect(find.text('Achats'), findsNothing);
    expect(find.text('Fournisseurs'), findsNothing);
    expect(find.text('Dettes'), findsNothing);
    expect(find.text('Historique paiements'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    expect(find.text('Documents'), findsNothing);
    expect(find.text('Paramètres'), findsNothing);
  });

  testWidgets('admin voit tous les modules', (tester) async {
    await pump(tester, admin);

    // Le menu contient plus d'items que la hauteur visible de la
    // fenêtre de test : on scrolle jusqu'à chaque item avant de
    // vérifier sa présence, plutôt que de dépendre de sa position.
    for (final label in [
      'Tableau de bord', 'Ventes', 'Achats', 'Articles', 'Clients',
      'Dettes', 'Historique paiements', 'Fournisseurs',
      'Stock', 'Documents', 'Paramètres',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
