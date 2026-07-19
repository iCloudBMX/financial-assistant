import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../providers/app_providers.dart';

class MortgageScenariosScreen extends ConsumerWidget {
  final int mortgageId;
  const MortgageScenariosScreen({super.key, required this.mortgageId});

  static const _labels = {
    ScenarioKind.mandatoryOnly: 'Faqat majburiy to\'lov',
    ScenarioKind.fixedExtraMonthly: 'Har oy qo\'shimcha',
    ScenarioKind.oneTimeExtra: 'Bir martalik qo\'shimcha',
    ScenarioKind.allRemainingIncome: 'Qolgan mablag\'ni to\'lash',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ssenariylar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (list) {
          MortgageWithProjection? item;
          for (final e in list) {
            if (e.mortgage.id == mortgageId) {
              item = e;
              break;
            }
          }
          if (item == null) return const Center(child: Text('Topilmadi'));
          final cur = CurrencyRegistry.byCode(item.mortgage.currencyCode);
          final mandatory = item.mortgage.mandatoryPaymentMinor;
          final sample = mandatory ~/ 10; // 10% sample extra
          final scenarios = compareScenarios(
            currentPrincipalMinor: item.currentPrincipalMinor,
            annualRateBp: item.mortgage.annualRateBp,
            type: item.mortgage.paymentType,
            monthlyPaymentMinor: mandatory,
            monthlyPrincipalMinor: item.monthlyPrincipalMinor,
            extraMonthlyMinor: sample,
            oneTimeExtraMinor: mandatory,
            remainingIncomeMinor: sample * 2,
            asOf: DateTime.now(),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final s in scenarios)
                Card(
                  child: ListTile(
                    title: Text(_labels[s.kind]!),
                    subtitle: Text(
                      s.neverCloses
                          ? 'Yopilmaydi'
                          : 'Qolgan oylar: ${s.monthsRemaining}\n'
                              'Tejalgan foiz: ${Money(s.interestSavedMinor, cur).format()}\n'
                              'Muddat qisqarishi: ${s.monthsSaved} oy\n'
                              'Oylik: ${Money(s.requiredMonthlyMinor, cur).format()}'
                              '${s.isApproximate ? '\n(taxminiy)' : ''}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
