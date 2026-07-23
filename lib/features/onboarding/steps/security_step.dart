import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/velora_tokens.dart';
import '../../../providers/app_providers.dart';
import '../../../ui/components/velora_status.dart';
import '../../security/pin_setup_sheet.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

/// Optional onboarding step: set a 4-digit PIN to lock the app. Skippable via
/// the shared "O'tkazib yuborish"/"Keyingi" controls -- skipping simply leaves
/// `appLockEnabled` at its default false. PIN-only; biometrics are offered in
/// Settings, not here.
///
/// "PIN already set this session" is read from the draft
/// (`settings.appLockEnabled`), not local state, so it survives the remount
/// that `OnboardingScreen` triggers when navigating back onto this step.
class SecurityStep extends OnboardingStep {
  @override
  String get id => 'security';
  @override
  String get title => 'Ilovangizni himoyalang';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      _SecurityStepBody(controller: controller, title: title);
}

class _SecurityStepBody extends ConsumerStatefulWidget {
  const _SecurityStepBody({required this.controller, required this.title});

  final OnboardingController controller;
  final String title;

  @override
  ConsumerState<_SecurityStepBody> createState() => _SecurityStepBodyState();
}

class _SecurityStepBodyState extends ConsumerState<_SecurityStepBody> {
  @override
  Widget build(BuildContext context) {
    // Read straight from the draft on every build (never cached in local
    // state) -- `setState` below only forces this widget to re-run `build`
    // when it isn't already being rebuilt by an ancestor (e.g. in isolation
    // in a test); `OnboardingScreen` itself already rebuilds this step on
    // every draft change via its own `ref.watch`, so this is belt-and-braces
    // for standalone use.
    final controller = widget.controller;
    final pinSet = controller.state.settings.appLockEnabled;
    return OnboardingStepScaffold(
      title: widget.title,
      lead: "4 raqamli PIN kod bilan ma'lumotlaringizni himoyalang. Buni "
          "keyinroq Sozlamalarda ham yoqishingiz mumkin.",
      children: [
        if (pinSet)
          const VeloraStatusBadge(
            key: Key('onboarding_security_pin_badge'),
            color: VeloraColors.success,
            icon: Icons.check_circle,
            label: "PIN o'rnatildi",
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('onboarding_security_set_pin'),
              style: FilledButton.styleFrom(
                backgroundColor: VeloraColors.plumTint,
                foregroundColor: VeloraColors.plum,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
              ),
              onPressed: () async {
                final ok = await showPinSetup(
                    context, ref.read(appLockControllerProvider));
                if (ok) {
                  controller.update((s) => s.copyWith(appLockEnabled: true));
                  if (mounted) setState(() {});
                }
              },
              child: const Text("PIN o'rnatish"),
            ),
          ),
      ],
    );
  }
}
