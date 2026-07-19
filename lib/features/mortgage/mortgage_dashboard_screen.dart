import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'mortgage_edit_sheet.dart';
import 'mortgage_payment_sheet.dart';
import 'mortgage_extra_payment_sheet.dart';
import 'mortgage_recommendations.dart';
import 'mortgage_scenarios_screen.dart';

class MortgageDashboardScreen extends ConsumerWidget {
  const MortgageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ipoteka')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ipoteka qo\'shilmagan'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => showMortgageEditSheet(context, ref),
                    child: const Text('Ipoteka qo\'shish'),
                  ),
                ],
              ),
            );
          }
          final m = list.first; // MVP: one primary mortgage on the dashboard
          final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
          Money money(int v) => Money(v, cur);
          final payoff = m.projection.neverCloses
              ? 'Joriy to\'lovda yopilmaydi'
              : (m.projection.payoffDate?.toString().split(' ').first ?? '—');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(m.mortgage.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              _row('Joriy qarz qoldig\'i', money(m.currentPrincipalMinor).format()),
              _row('Yillik foiz', '${(m.mortgage.annualRateBp / 100).toStringAsFixed(2)}%'),
              _row('Navbatdagi to\'lov', money(m.mortgage.mandatoryPaymentMinor).format()),
              _row('Navbatdagi sana',
                  m.mortgage.nextPaymentDate.toString().split(' ').first),
              _row('Jami to\'langan', money(m.totals.paidMinor).format()),
              _row('Asosiy qarzga', money(m.totals.principalPaidMinor).format()),
              _row('Foizga', money(m.totals.interestPaidMinor).format()),
              _row('Qo\'shimcha to\'lovlar', money(m.totals.extraPaidMinor).format()),
              _row('Bajarilishi', '${(m.completionBp / 100).toStringAsFixed(1)}%'),
              _row('Taxminiy yopilish', payoff),
              const SizedBox(height: 16),
              MortgageRecommendations(item: m),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                FilledButton(
                  onPressed: () =>
                      showMortgagePaymentSheet(context, ref, m.mortgage.id),
                  child: const Text('To\'lov kiritish'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      showMortgageExtraPaymentSheet(context, ref, m.mortgage.id),
                  child: const Text('Qo\'shimcha to\'lov'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          MortgageScenariosScreen(mortgageId: m.mortgage.id))),
                  child: const Text('Ssenariylar'),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
      );
}
