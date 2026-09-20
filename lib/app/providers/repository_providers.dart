import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/article_repository_impl.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../data/repositories/supplier_repository_impl.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../data/repositories/quote_repository_impl.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../data/repositories/purchase_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/receipt_repository_impl.dart';
import '../../data/repositories/inventory_repository_impl.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/article_repository.dart';
import '../../domain/repositories/client_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../domain/repositories/store_repository.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../core/services/draft_service.dart';

/// Instance unique de la base de données, partagée par toute
/// l'application via Riverpod.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(databaseProvider)),
);

final articleRepositoryProvider = Provider<ArticleRepository>(
  (ref) => ArticleRepositoryImpl(ref.watch(databaseProvider)),
);

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepositoryImpl(ref.watch(databaseProvider)),
);

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => SupplierRepositoryImpl(ref.watch(databaseProvider)),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepositoryImpl(ref.watch(databaseProvider)),
);

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepositoryImpl(ref.watch(databaseProvider)),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepositoryImpl(ref.watch(databaseProvider)),
);

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepositoryImpl(ref.watch(databaseProvider)),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepositoryImpl(ref.watch(databaseProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepositoryImpl(ref.watch(databaseProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(databaseProvider)),
);

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepositoryImpl(ref.watch(databaseProvider)),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepositoryImpl(ref.watch(databaseProvider)),
);

final draftServiceProvider = Provider<DraftService>(
  (ref) => DraftService(ref.watch(databaseProvider).draftDao),
);
