import 'package:intl/intl.dart';

/// Formatage monétaire en Francs CFA (devise utilisée au Mali).
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _format = NumberFormat.decimalPattern('fr_FR');

  static String format(double montant) {
    return '${_format.format(montant)} FCFA';
  }

  static String formatSansDevise(double montant) {
    return _format.format(montant);
  }
}
