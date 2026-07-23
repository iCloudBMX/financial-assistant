import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../shell/routes.dart';
import 'onboarding_controller.dart';
import 'onboarding_step.dart';
import 'steps/security_step.dart';
import 'steps/welcome_step.dart';

/// A deliberately minimal onboarding: just the welcome + name, then the App
/// Lock (PIN/biometric) configuration. Everything else (currency, period,
/// first account, baseline, theme) keeps its sensible default and is
/// adjustable later from Settings, so setup reads as an invitation, not a
/// form. Later sub-projects can override this provider to append steps.
final onboardingStepsProvider = Provider<List<OnboardingStep>>(
  (ref) => [WelcomeStep(), SecurityStep()],
);

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
    final theme = Theme.of(context);
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
              padding: const EdgeInsets.fromLTRB(
                VeloraSpacing.xl,
                VeloraSpacing.lg,
                VeloraSpacing.xl,
                VeloraSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The `velora.` wordmark leads every step: brand first, so
                  // setup reads as an invitation, not a form. Fixed size /
                  // ellipsis so it never pushes the eyebrow off-screen at
                  // large accessibility text scales.
                  Text(
                    'velora.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: VeloraColors.plum,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: VeloraSpacing.md),
                  // A slim segmented progress indicator: position, not
                  // pressure (design spec sec. 6.1). One filled plum segment
                  // per reached step.
                  Row(
                    key: const Key('onboarding_progress'),
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        Expanded(
                          child: Container(
                            height: 5,
                            margin: EdgeInsets.only(
                              right: i == steps.length - 1
                                  ? 0
                                  : VeloraSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: i <= draft.index
                                  ? VeloraColors.plum
                                  : VeloraColors.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: VeloraSpacing.md),
                  Text(
                    '${draft.index + 1} / ${steps.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VeloraColors.coral,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: KeyedSubtree(
                  key: ValueKey(step.id),
                  child: step.build(context, controller),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VeloraSpacing.xl,
                vertical: VeloraSpacing.lg,
              ),
              child: Column(
                children: [
                  // The single coral primary CTA from the mockup -- full
                  // width, so "Davom etish" / "Yakunlash" is always the one
                  // obvious next move.
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const Key('onboarding_next_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: VeloraColors.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            VeloraRadii.control,
                          ),
                        ),
                      ),
                      onPressed: finishOrAdvance,
                      child: Text(controller.isLast ? 'Yakunlash' : 'Keyingi'),
                    ),
                  ),
                  const SizedBox(height: VeloraSpacing.sm),
                  // Back / skip stay quiet and secondary. `Wrap` (not `Row`)
                  // so at 200% text scale / 320px width they fall onto their
                  // own lines instead of overflowing.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: VeloraSpacing.sm,
                    runSpacing: VeloraSpacing.xs,
                    children: [
                      TextButton(
                        key: const Key('onboarding_back_button'),
                        onPressed: draft.index > 0 ? controller.back : null,
                        style: TextButton.styleFrom(
                          foregroundColor: VeloraColors.plum,
                        ),
                        child: const Text('Orqaga'),
                      ),
                      if (!controller.isLast)
                        TextButton(
                          key: const Key('onboarding_skip_button'),
                          onPressed: controller.next,
                          style: TextButton.styleFrom(
                            foregroundColor: VeloraColors.muted,
                          ),
                          child: const Text("O'tkazib yuborish"),
                        ),
                    ],
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
