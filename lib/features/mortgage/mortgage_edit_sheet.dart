// STUB — Task 9 replaces this with the real add/edit mortgage form sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mortgage/mortgage_model.dart';

Future<void> showMortgageEditSheet(BuildContext context, WidgetRef ref,
    {Mortgage? existing}) async {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SizedBox.shrink(),
  );
}
