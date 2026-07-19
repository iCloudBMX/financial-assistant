// STUB — Task 10 replaces this with the real record-payment sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showMortgagePaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) async {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SizedBox.shrink(),
  );
}
