import 'package:flutter/material.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class WelcomeStep extends OnboardingStep {
  @override
  String get id => 'welcome';
  @override
  String get title => 'Xush kelibsiz';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Ismingiz'),
              onChanged: (t) =>
                  controller.update((s) => s.copyWith(name: t)),
            ),
          ],
        ),
      );
}
