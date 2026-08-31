import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/app/providers/repository_providers.dart';
import 'package:malistock_pro/app/providers/session_provider.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/domain/entities/document_type.dart';
import 'package:malistock_pro/domain/entities/user.dart';
import 'package:malistock_pro/presentation/commercial_documents/documents_list_screen.dart';

/// Vérifie qu'un employé ne voit, dans "Ventes", que les factures qu'il
/// a lui-même créées — pas celles de ses collègues — alors qu'un admin
/// voit tout. Widget de production (`DocumentsListScreen`) branché sur
/// une vraie base SQLite en mémoire, pas une relecture du code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int employeId;
  late int autreVendeurId;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());

    final storeId =
        await db.into(db.stores).insert(StoresCompanion.insert(nom: 'Boutique'));
    employeId = await db.into(db.users).insert(UsersCompanion.insert(
          nom: 'Employé A',
          login: 'employeA',
          motDePasseHash: 'x',
          role: 'employe',
        ));
    autreVendeurId = await db.into(db.users).insert(UsersCompanion.insert(
          nom: 'Employé B',
          login: 'employeB',
          motDePasseHash: 'x',
          role: 'employe',
        ));

    // Vente créée par l'employé connecté.
    await db.into(db.commercialDocuments).insert(CommercialDocumentsCompanion.insert(
          numero: 'FAC-2026-0001',
          type: 'facture',
          statut: const Value('valide'),
          storeId: storeId,
          dateDocument: DateTime.now(),
          createdById: Value(employeId),
          totalTtc: const Value(1000),
        ));

    // Vente créée par un collègue.
    await db.into(db.commercialDocuments).insert(CommercialDocumentsCompanion.insert(
          numero: 'FAC-2026-0002',
          type: 'facture',
          statut: const Value('valide'),
          storeId: storeId,
          dateDocument: DateTime.now(),
          createdById: Value(autreVendeurId),
          totalTtc: const Value(2000),
        ));
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, UserEntity user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => SessionNotifier()..setUser(user)),
        ],
        child: const MaterialApp(
          home: DocumentsListScreen(type: DocumentType.facture),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('un employé ne voit que ses propres ventes', (tester) async {
    final employe = UserEntity(
      id: employeId,
      nom: 'Employé A',
      login: 'employeA',
      role: 'employe',
      actif: true,
      dateCreation: DateTime(2026),
    );

    await pump(tester, employe);

    expect(find.text('FAC-2026-0001'), findsOneWidget);
    expect(find.text('FAC-2026-0002'), findsNothing);
  });

  testWidgets('un admin voit toutes les ventes', (tester) async {
    final admin = UserEntity(
      id: 99,
      nom: 'Admin',
      login: 'admin',
      role: 'admin',
      actif: true,
      dateCreation: DateTime(2026),
    );

    await pump(tester, admin);

    expect(find.text('FAC-2026-0001'), findsOneWidget);
    expect(find.text('FAC-2026-0002'), findsOneWidget);
  });
}
