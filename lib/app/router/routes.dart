/// Centralise tous les chemins de navigation de l'application.
class Routes {
  Routes._();

  static const login = '/login';
  static const dashboard = '/dashboard';

  static const articles = '/articles';
  static const articleNew = '/articles/new';
  static const articleImport = '/articles/import';
  static const articleEdit = '/articles/:id/edit';

  static const clients = '/clients';
  static const clientNew = '/clients/new';
  static const clientDetail = '/clients/:id';
  static const clientEdit = '/clients/:id/edit';

  static const suppliers = '/suppliers';

  static const quotes = '/quotes';
  static const quoteNew = '/quotes/new';

  static const invoices = '/invoices';
  static const invoiceNew = '/invoices/new';
  static const invoiceDetail = '/invoices/:id';

  static const debts = '/debts';
  static const stores = '/stores';
  static const stock = '/stock';
  static const settings = '/settings';
}
