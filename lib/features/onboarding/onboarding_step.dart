import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import 'onboarding_controller.dart';

abstract class OnboardingStep {
  String get id;
  String get title;

  /// One calm sentence under the question (design spec sec. 6.1: "one clear
  /// question per step"). Null when a step's controls speak for themselves.
  String? get lead => null;

  Widget build(BuildContext context, OnboardingController controller);
}

/// The shared "Velora Human" body for every onboarding step: one bold
/// question, an optional calm lead line, then the step's own controls in a
/// single stretched column. Centralizing it here keeps all six steps visually
/// identical (warm blush field surfaces, consistent rhythm) without each step
/// re-implementing the header. The screen chrome (wordmark, progress, CTA)
/// lives in `OnboardingScreen`; this is only the per-step question + inputs.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.title,
    required this.children,
    this.lead,
  });

  final String title;
  final String? lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.xl,
        vertical: VeloraSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (lead != null) ...[
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              lead!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VeloraColors.muted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: VeloraSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

/// A soft blush-on-white field surface used by the picker-style steps
/// (currency, period, appearance) so a bare Material dropdown/segment reads as
/// a rounded Velora card rather than a flat control on the blush background.
class OnboardingFieldTile extends StatelessWidget {
  const OnboardingFieldTile({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.lg,
        vertical: VeloraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: VeloraColors.muted,
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          child,
        ],
      ),
    );
  }
}
