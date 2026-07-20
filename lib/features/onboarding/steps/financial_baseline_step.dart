import 'package:flutter/material.dart';

import '../../../core/theme/velora_tokens.dart';
import '../../../ui/components/velora_money_field.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

/// Onboarding step 4 (design spec sec. 6.1): the free-spending (variable)
/// budget and the minimal reserve the user never wants to dip below. Both
/// fields write straight to the in-progress [OnboardingDraft], exactly like
/// every other Foundation-style step, so they are only persisted when
/// [OnboardingController.commit] runs at the end -- which is what makes the
/// step skippable with no extra affordance: the shared "Keyingi"/"O'tkazib
/// yuborish" controls move on and the (zero) defaults stay in place, fully
/// editable later in Settings.
class FinancialBaselineStep extends OnboardingStep {
  @override
  String get id => 'financial-baseline';
  @override
  String get title => 'Moliyaviy asos';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      _FinancialBaselineStepBody(controller: controller, title: title);
}

class _FinancialBaselineStepBody extends StatefulWidget {
  const _FinancialBaselineStepBody({
    required this.controller,
    required this.title,
  });

  final OnboardingController controller;
  final String title;

  @override
  State<_FinancialBaselineStepBody> createState() =>
      _FinancialBaselineStepBodyState();
}

class _FinancialBaselineStepBodyState
    extends State<_FinancialBaselineStepBody> {
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _reserveCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.state.settings;
    _budgetCtrl = TextEditingController(
      text: s.variableBudget.minorUnits == 0
          ? ''
          : s.variableBudget.formatNumber(),
    );
    _reserveCtrl = TextEditingController(
      text: s.minReserve.minorUnits == 0 ? '' : s.minReserve.formatNumber(),
    );
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _reserveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.controller.state.settings.primaryCurrency;
    return OnboardingStepScaffold(
      title: widget.title,
      lead: 'Erkin xarajatlar uchun oylik byudjet va tegilmaydigan zaxira. '
          'Taxminiy summalar yetarli.',
      children: [
        VeloraMoneyField(
          key: const Key('onboarding_variable_budget'),
          controller: _budgetCtrl,
          currency: currency,
          label: 'Erkin xarajat byudjeti',
          onChanged: (m) {
            if (m == null) return;
            widget.controller.update((s) => s.copyWith(variableBudget: m));
          },
        ),
        const SizedBox(height: VeloraSpacing.lg),
        VeloraMoneyField(
          key: const Key('onboarding_min_reserve'),
          controller: _reserveCtrl,
          currency: currency,
          label: 'Minimal zaxira',
          onChanged: (m) {
            if (m == null) return;
            widget.controller.update((s) => s.copyWith(minReserve: m));
          },
        ),
      ],
    );
  }
}
