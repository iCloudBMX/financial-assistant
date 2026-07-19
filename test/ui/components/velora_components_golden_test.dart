import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';
import 'package:financial_assistant/ui/components/velora_async_state.dart';
import 'package:financial_assistant/ui/components/velora_button.dart';
import 'package:financial_assistant/ui/components/velora_card.dart';
import 'package:financial_assistant/ui/components/velora_sheet.dart';
import 'package:financial_assistant/ui/components/velora_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _previewKey = ValueKey('velora-components-preview');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Onest',
    )..addFont(rootBundle.load('assets/fonts/Onest-Variable.ttf'))).load();
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final testCase in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets(
      'renders ${testCase.name} components at 320px and 200 percent text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1280));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_ComponentsPreview(theme: testCase.theme));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(_previewKey),
          matchesGoldenFile('goldens/velora_components_${testCase.name}.png'),
        );
      },
    );
  }
}

class _ComponentsPreview extends StatelessWidget {
  const _ComponentsPreview({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _previewKey,
        child: VeloraSheetScaffold(
          title: 'Umumiy holatlar',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VeloraCard(
                onTap: () {},
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
              const Align(
                alignment: Alignment.centerLeft,
                child: VeloraStatusBadge(
                  color: VeloraColors.success,
                  icon: Icons.check_circle,
                  label: 'Reja bo\u2018yicha',
                ),
              ),
              const SizedBox(height: VeloraSpacing.md),
              const VeloraEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Hali yozuvlar yo\u2018q',
                message: 'Yangi xarajat shu yerda ko\u2018rinadi.',
              ),
              VeloraErrorState(
                message: 'Ma\u2019lumotlarni yuklab bo\u2018lmadi',
                onRetry: () {},
              ),
              const VeloraSkeleton(width: double.infinity, height: 72),
              const SizedBox(height: VeloraSpacing.md),
              VeloraPrimaryButton(
                label: 'Saqlanmoqda',
                loading: true,
                onPressed: () {},
              ),
            ],
          ),
          primaryAction: VeloraPrimaryButton(
            label: 'Davom etish',
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}
