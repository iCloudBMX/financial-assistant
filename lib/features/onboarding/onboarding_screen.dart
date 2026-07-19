import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../shell/routes.dart';
import 'onboarding_controller.dart';
import 'onboarding_step.dart';
import 'steps/account_step.dart';
import 'steps/currency_step.dart';
import 'steps/financial_baseline_step.dart';
import 'steps/period_step.dart';
import 'steps/theme_step.dart';
import 'steps/welcome_step.dart';

/// Foundation's ordered onboarding steps, progressive and skippable
/// (design spec sec. 6.1): welcome+name, currency, financial-period start,
/// first account + opening balance, financial baseline (variable budget +
/// minimal reserve), and appearance. Later sub-projects can override this
/// provider to insert/append their own steps without touching Foundation
/// code.
final onboardingStepsProvider = Provider<List<OnboardingStep>>((ref) => [
      WelcomeStep(),
      CurrencyStep(),
      PeriodStep(),
      AccountStep(),
      FinancialBaselineStep(),
      ThemeStep(),
    ]);

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingDraft>((ref) {
  final stepCount = ref.watch(onboardingStepsProvider).length;
  return OnboardingController(
    settingsRepo: ref.watch(settingsRepositoryProvider),
    metaRepo: ref.watch(metaRepositoryProvider),
    stepCount: stepCount,
  );
});

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(onboardingStepsProvider);
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final step = steps[draft.index];

    Future<void> finishOrAdvance() async {
      if (controller.isLast) {
        await controller.commit();
        if (context.mounted) {
          context.goNamed(RouteNames.home);
        }
      } else {
        controller.next();
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VeloraSpacing.xl,
                vertical: VeloraSpacing.md,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(VeloraRadii.control),
                child: LinearProgressIndicator(
                  key: const Key('onboarding_progress'),
                  value: (draft.index + 1) / steps.length,
                  minHeight: 6,
                  color: VeloraColors.coral,
                  backgroundColor: VeloraColors.coral.withValues(alpha: 0.15),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: KeyedSubtree(
                    key: ValueKey(step.id),
                    child: step.build(context, controller),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VeloraSpacing.xl,
                vertical: VeloraSpacing.lg,
              ),
              // `Wrap` (not `Row`) so at 200% text scale / 320px width the
              // three controls fall onto their own line instead of
              // overflowing -- "Orqaga"/"O'tkazib yuborish"/"Keyingi" never
              // all fit on one line together at that scale.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: VeloraSpacing.sm,
                runSpacing: VeloraSpacing.xs,
                children: [
                  TextButton(
                    key: const Key('onboarding_back_button'),
                    onPressed: draft.index > 0 ? controller.back : null,
                    child: const Text('Orqaga'),
                  ),
                  if (!controller.isLast)
                    TextButton(
                      key: const Key('onboarding_skip_button'),
                      onPressed: controller.next,
                      child: const Text("O'tkazib yuborish"),
                    ),
                  FilledButton(
                    key: const Key('onboarding_next_button'),
                    onPressed: finishOrAdvance,
                    child: Text(controller.isLast ? 'Yakunlash' : 'Keyingi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
