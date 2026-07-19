// STUB — Task 11 replaces this with the real extra-payment sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showMortgageExtraPaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) async {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SizedBox.shrink(),
  );
}
