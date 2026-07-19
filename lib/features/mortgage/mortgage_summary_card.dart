import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'mortgage_dashboard_screen.dart';

class MortgageSummaryCard extends ConsumerWidget {
  const MortgageSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        void open() => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MortgageDashboardScreen()));
        if (list.isEmpty) return const SizedBox.shrink();
        final m = list.first;
        final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
        return Card(
          child: ListTile(
            title: const Text('Ipoteka'),
            subtitle: Text(
                '${m.mortgage.name} • ${Money(m.currentPrincipalMinor, cur).format()}'),
            trailing: Text('${(m.completionBp / 100).toStringAsFixed(0)}%'),
            onTap: open,
          ),
        );
      },
    );
  }
}
