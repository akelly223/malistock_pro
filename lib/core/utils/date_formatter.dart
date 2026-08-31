import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dayMonthFormat = DateFormat('dd/MM');
  static const _moisCourts = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jui',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String formatDayMonth(DateTime date) => _dayMonthFormat.format(date);

  static String formatMonthShort(DateTime date) =>
      _moisCourts[date.month - 1];
}
