import 'dart:ui' show Tristate;

import 'package:financial_assistant/ui/components/velora_async_state.dart';
import 'package:financial_assistant/ui/components/velora_button.dart';
import 'package:financial_assistant/ui/components/velora_card.dart';
import 'package:financial_assistant/ui/components/velora_sheet.dart';
import 'package:financial_assistant/ui/components/velora_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary button is at least 48px and exposes its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VeloraPrimaryButton(label: 'Saqlash', onPressed: () {}),
      ),
    );

    expect(
      tester.getSize(find.byType(VeloraPrimaryButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSemantics(find.text('Saqlash')).label,
      contains('Saqlash'),
    );
  });

  testWidgets('loading primary button disables presses and shows progress', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VeloraPrimaryButton(
          label: 'Saqlash',
          loading: true,
          onPressed: () => presses++,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));

    expect(presses, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading primary button preserves its accessible action state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VeloraPrimaryButton(
          label: 'Saqlash',
          loading: true,
          onPressed: () {},
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(VeloraPrimaryButton));
    expect(node.label, 'Saqlash');
    expect(node.value, 'Yuklanmoqda');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('card exposes its child and responds to taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: VeloraCard(
          onTap: () => tapped = true,
          child: const Text('Balans'),
        ),
      ),
    );

    await tester.tap(find.text('Balans'));

    expect(tapped, isTrue);
    expect(find.text('Balans'), findsOneWidget);
  });

  testWidgets('tappable card enforces a 48 by 48 minimum target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VeloraCard(
            padding: EdgeInsets.zero,
            onTap: () {},
            child: const SizedBox.square(dimension: 8),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(VeloraCard)), const Size(48, 48));
  });

  testWidgets('non-tappable card remains content-sized', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: VeloraCard(
            padding: EdgeInsets.zero,
            child: SizedBox.square(dimension: 8),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(VeloraCard)), const Size(8, 8));
  });

  testWidgets('status badge combines icon label and color', (tester) async {
    const statusColor = Color(0xFF2E9D7C);
    await tester.pumpWidget(
      const MaterialApp(
        home: VeloraStatusBadge(
          color: statusColor,
          icon: Icons.check_circle,
          label: 'Xavfsiz',
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Xavfsiz'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
      statusColor,
    );
  });

  testWidgets('status badge announces its label once', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: VeloraStatusBadge(
            color: Color(0xFF2E9D7C),
            icon: Icons.check_circle,
            label: 'Xavfsiz',
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(VeloraStatusBadge)).label,
      'Xavfsiz',
    );
  });

  testWidgets('error state exposes cause and retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VeloraErrorState(message: 'Saqlanmadi', onRetry: () => retries++),
      ),
    );

    expect(find.text('Saqlanmadi'), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);

    await tester.tap(find.text('Qayta urinish'));
    expect(retries, 1);
  });

  testWidgets('empty state exposes its guidance and optional action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VeloraEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Hali tranzaksiya yo\u2018q',
          message: 'Birinchi xarajatingizni kiriting.',
          action: Text('Xarajat qo\u2018shish'),
        ),
      ),
    );

    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.text('Hali tranzaksiya yo\u2018q'), findsOneWidget);
    expect(find.text('Birinchi xarajatingizni kiriting.'), findsOneWidget);
    expect(find.text('Xarajat qo\u2018shish'), findsOneWidget);
  });

  testWidgets('skeleton preserves the requested layout geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: VeloraSkeleton(width: 180, height: 72)),
      ),
    );

    expect(tester.getSize(find.byType(VeloraSkeleton)), const Size(180, 72));
  });

  testWidgets('sheet keeps a scroll body and one fixed CTA above keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: const EdgeInsets.only(bottom: 240),
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: VeloraSheetScaffold(
          title: 'Yangi xarajat',
          body: const Column(
            children: [
              SizedBox(height: 400),
              Text('Tafsilotlar'),
              SizedBox(height: 400),
            ],
          ),
          primaryAction: VeloraPrimaryButton(
            label: 'Saqlash',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SafeArea), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Yangi xarajat'), findsOneWidget);
    expect(find.text('Saqlash'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(VeloraPrimaryButton)).dy,
      lessThanOrEqualTo(460),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('components reflow at 320px width and 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const VeloraCard(
                  child: Text(
                    'Majburiy xarajatlardan keyingi mavjud mablag\u2018',
                  ),
                ),
                const VeloraStatusBadge(
                  color: Color(0xFFFFB46A),
                  icon: Icons.info,
                  label: 'Limitga yaqin',
                ),
                const VeloraEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Bu davr uchun yozuvlar yo\u2018q',
                  message:
                      'Yangi yozuv qo\u2018shilganda shu yerda ko\u2018rinadi.',
                ),
                VeloraErrorState(
                  message: 'Ma\u2019lumotlarni yuklab bo\u2018lmadi',
                  onRetry: () {},
                ),
                const VeloraSkeleton(width: double.infinity, height: 72),
                VeloraPrimaryButton(
                  label: 'O\u2018zgarishlarni saqlash',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(VeloraPrimaryButton)),
      ).scale(10),
      20,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(VeloraPrimaryButton)).width,
      lessThanOrEqualTo(320),
    );
  });
}
