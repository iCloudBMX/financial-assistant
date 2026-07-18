import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../shell/routes.dart';
import 'onboarding_controller.dart';
import 'onboarding_step.dart';
import 'steps/currency_step.dart';
import 'steps/period_step.dart';
import 'steps/reserve_step.dart';
import 'steps/theme_step.dart';
import 'steps/welcome_step.dart';

/// Foundation's ordered onboarding steps. Later sub-projects can override
/// this provider to insert/append their own steps without touching
/// Foundation code.
final onboardingStepsProvider = Provider<List<OnboardingStep>>((ref) => [
      WelcomeStep(),
      CurrencyStep(),
      PeriodStep(),
      ReserveStep(),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (draft.index + 1) / steps.length,
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
                horizontal: 24,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: draft.index > 0 ? controller.back : null,
                    child: const Text('Orqaga'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (controller.isLast) {
                        await controller.commit();
                        if (context.mounted) {
                          context.go(RouteNames.home);
                        }
                      } else {
                        controller.next();
                      }
                    },
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
