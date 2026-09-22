import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/services/tva_calculation_service.dart';
import 'package:malistock_pro/core/widgets/document_ligne_tile.dart';
import 'package:malistock_pro/domain/entities/document_input.dart';
import 'package:malistock_pro/presentation/commercial_documents/providers/document_form_notifier.dart';

/// Reproduit une frappe clavier incrémentale ("1" → "10" → "100"), avec
/// rebuild du parent entre chaque chiffre comme le fait
/// DocumentLinesEditor, pour vérifier que le champ Qté accepte une
/// saisie de plus de 2 chiffres sans que didUpdateWidget ne réinitialise
/// inutilement le curseur/controller à chaque frappe.
void main() {
  testWidgets(
    'le champ Qté accepte une saisie clavier de 3 chiffres et plus',
    (tester) async {
      double? dernierQuantiteEmise;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _HarnaisTest(
              onQuantiteChangee: (q) => dernierQuantiteEmise = q,
            ),
          ),
        ),
      );

      final champQte = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Qté',
      );
      expect(champQte, findsOneWidget);

      await tester.enterText(champQte, '1');
      await tester.pump();
      await tester.enterText(champQte, '10');
      await tester.pump();

      // Le curseur ne doit pas avoir été réinitialisé par un
      // réassignement inutile du controller après le 2e chiffre : c'est
      // ce réassignement (même à valeur identique) qui désynchronise la
      // saisie clavier native et bloquait le 3e chiffre.
      final controllerApres2Chiffres =
          tester.widget<TextField>(champQte).controller!;
      expect(controllerApres2Chiffres.selection.baseOffset, isNot(-1));

      await tester.enterText(champQte, '100');
      await tester.pump();

      expect(dernierQuantiteEmise, 100);
      expect(tester.widget<TextField>(champQte).controller!.text, '100');
    },
  );

  testWidgets('quantité 0 ou négative est ramenée à 1', (tester) async {
    double? dernierQuantiteEmise;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _HarnaisTest(
            onQuantiteChangee: (q) => dernierQuantiteEmise = q,
          ),
        ),
      ),
    );

    final champQte = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Qté',
    );

    await tester.enterText(champQte, '0');
    await tester.pump();

    expect(dernierQuantiteEmise, 1);
  });

  testWidgets('quantité décimale est acceptée', (tester) async {
    double? dernierQuantiteEmise;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _HarnaisTest(
            onQuantiteChangee: (q) => dernierQuantiteEmise = q,
          ),
        ),
      ),
    );

    final champQte = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Qté',
    );

    await tester.enterText(champQte, '10.5');
    await tester.pump();

    expect(dernierQuantiteEmise, 10.5);
  });
}

class _HarnaisTest extends StatefulWidget {
  final ValueChanged<double> onQuantiteChangee;
  const _HarnaisTest({required this.onQuantiteChangee});

  @override
  State<_HarnaisTest> createState() => _HarnaisTestState();
}

class _HarnaisTestState extends State<_HarnaisTest> {
  late DocumentLigneFormItem _item;

  @override
  void initState() {
    super.initState();
    _item = _construireItem(1);
  }

  DocumentLigneFormItem _construireItem(double quantite) {
    final input = DocumentLigneInput(
      articleId: 1,
      articleCode: 'ART1',
      articleNom: 'Article test',
      quantite: quantite,
      prixUnitaireHt: 1000,
      tauxTva: 0,
    );
    return DocumentLigneFormItem(
      input: input,
      totaux: DocumentLineTotals(
        totalHt: quantite * 1000,
        montantTva: 0,
        totalTtc: quantite * 1000,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentLigneTile(
      item: _item,
      index: 0,
      onChanged: (input) {
        widget.onQuantiteChangee(input.quantite);
        setState(() => _item = _construireItem(input.quantite));
      },
      onRemove: () {},
    );
  }
}
