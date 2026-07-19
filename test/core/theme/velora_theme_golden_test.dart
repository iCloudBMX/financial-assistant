import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _previewKey = ValueKey('velora-theme-preview');

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
    testWidgets('renders the representative ${testCase.name} theme surface', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_ThemePreview(theme: testCase.theme));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(_previewKey),
        matchesGoldenFile('goldens/velora_theme_${testCase.name}.png'),
      );
    });
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: RepaintBoundary(
      key: _previewKey,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 312,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(VeloraRadii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(VeloraSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bugun', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: VeloraSpacing.sm),
                    Text('Xavfsiz sarflash', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: VeloraSpacing.xs),
                    Text('12 500 000 so‘m', style: theme.textTheme.titleLarge),
                    const SizedBox(height: VeloraSpacing.lg),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: VeloraColors.success,
                        ),
                        const SizedBox(width: VeloraSpacing.sm),
                        Expanded(
                          child: Text(
                            'Reja bo‘yicha',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(
                              VeloraRadii.control,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VeloraSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Davom etish'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
