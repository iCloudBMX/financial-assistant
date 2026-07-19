import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/ui/components/account_card_picker.dart';
import 'package:financial_assistant/ui/components/category_picker.dart';
import 'package:financial_assistant/ui/components/velora_async_state.dart';
import 'package:financial_assistant/ui/components/velora_button.dart';
import 'package:financial_assistant/ui/components/velora_card.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';
import 'package:financial_assistant/ui/components/velora_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

void main() {
  testWidgets('foundation components match approved light and dark visuals', (
    tester,
  ) async {
    await pumpVelora(
      tester,
      child: const FoundationGallery(),
      size: phone390,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(FoundationGallery),
      matchesGoldenFile('baselines/foundation-light.png'),
    );

    await pumpVelora(
      tester,
      child: const FoundationGallery(),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(FoundationGallery),
      matchesGoldenFile('baselines/foundation-dark-320-scale200.png'),
    );
  });

  testWidgets('pumpVelora applies the requested device and text scale', (
    tester,
  ) async {
    const probeKey = Key('media-query-probe');

    await pumpVelora(
      tester,
      child: Builder(
        builder: (context) => SizedBox(
          key: probeKey,
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.textScalerOf(context).scale(10),
        ),
      ),
      size: phone320,
      textScale: textScale200,
    );

    final context = tester.element(find.byKey(probeKey));
    expect(tester.view.devicePixelRatio, 1);
    expect(MediaQuery.sizeOf(context), phone320);
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
  });
}

class FoundationGallery extends StatefulWidget {
  const FoundationGallery({super.key});

  @override
  State<FoundationGallery> createState() => _FoundationGalleryState();
}

class _FoundationGalleryState extends State<FoundationGallery> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1 250 000');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VeloraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Velora asoslari', style: theme.textTheme.headlineSmall),
              const SizedBox(height: VeloraSpacing.md),
              VeloraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xavfsiz sarflash', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: VeloraSpacing.xs),
                    Text(
                      '1 250 000 so\u2018m',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VeloraSpacing.md),
              VeloraMoneyField(
                controller: _amountController,
                currency: CurrencyRegistry.uzs,
                label: 'Summa',
              ),
              const SizedBox(height: VeloraSpacing.md),
              const Wrap(
                spacing: VeloraSpacing.sm,
                runSpacing: VeloraSpacing.sm,
                children: [
                  VeloraStatusBadge(
                    color: VeloraColors.success,
                    icon: Icons.check_circle,
                    label: 'Reja bo\u2018yicha',
                  ),
                  VeloraStatusBadge(
                    color: VeloraColors.apricot,
                    icon: Icons.warning_amber_rounded,
                    label: 'Limitga yaqin',
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.md),
              VeloraPrimaryButton(label: 'Davom etish', onPressed: () {}),
              const SizedBox(height: VeloraSpacing.sm),
              VeloraPrimaryButton(
                label: 'Saqlanmoqda',
                loading: true,
                onPressed: () {},
              ),
              const SizedBox(height: VeloraSpacing.md),
              const VeloraSkeleton(width: double.infinity, height: 64),
              VeloraErrorState(
                message: 'Ma\u2019lumotlarni yuklab bo\u2018lmadi',
                onRetry: () {},
              ),
              AccountCardPicker(
                accounts: _accounts,
                availableBalances: _balances,
                selectedId: 1,
                onSelected: (_) {},
              ),
              CategoryPicker(
                categories: _categories,
                quickIds: const [1, 2, 3, 4],
                selectedId: 1,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _accounts = [
  Account(
    id: 1,
    name: 'Karta',
    type: AccountType.bankCard,
    openingBalance: Money(12500000, CurrencyRegistry.uzs),
    icon: 'credit_card',
    archived: false,
  ),
  Account(
    id: 2,
    name: 'Naqd',
    type: AccountType.cash,
    openingBalance: Money(2400000, CurrencyRegistry.uzs),
    icon: 'payments',
    archived: false,
  ),
];

const _balances = {
  1: Money(12500000, CurrencyRegistry.uzs),
  2: Money(2400000, CurrencyRegistry.uzs),
};

const _categories = [
  Category(
    id: 1,
    name: 'Oziq',
    icon: 'restaurant',
    isDefault: true,
    archived: false,
  ),
  Category(
    id: 2,
    name: 'Yo\u2018l',
    icon: 'directions_car',
    isDefault: true,
    archived: false,
  ),
  Category(
    id: 3,
    name: 'Uy',
    icon: 'home',
    isDefault: true,
    archived: false,
    kind: CategoryKind.mandatory,
  ),
  Category(
    id: 4,
    name: 'Ilm',
    icon: 'school',
    isDefault: true,
    archived: false,
  ),
];
