import 'package:intl/intl.dart';

String formatDate(DateTime date, String pattern) =>
    DateFormat(pattern).format(date);

String formatCount(int n) {
  final f = NumberFormat.decimalPattern();
  // Force space grouping regardless of ambient locale.
  final grouped = f.format(n).replaceAll(RegExp(r'[., ]'), ' ');
  return grouped.trim();
}
