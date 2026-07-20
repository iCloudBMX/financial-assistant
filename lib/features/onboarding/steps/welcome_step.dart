import 'package:flutter/material.dart';
import '../../../core/theme/velora_tokens.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class WelcomeStep extends OnboardingStep {
  @override
  String get id => 'welcome';
  @override
  String get title => 'Xush kelibsiz';
  @override
  String get lead =>
      'Velora xarajat, maqsad va ipotekani bitta sokin moliyaviy rejada '
      'birlashtiradi. Sizni qanday atasak bo\'ladi?';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      OnboardingStepScaffold(
        title: title,
        lead: lead,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Ismingiz',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(VeloraRadii.control),
                ),
              ),
            ),
            onChanged: (t) => controller.update((s) => s.copyWith(name: t)),
          ),
        ],
      );
}
