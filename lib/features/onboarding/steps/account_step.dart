import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ledger/account.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/velora_tokens.dart';
import '../../../ui/components/velora_money_field.dart';
import '../../../ui/components/velora_status.dart';
import '../../accounts/account_labels.dart';
import '../../accounts/accounts_controller.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

/// Onboarding step 3 (design spec sec. 6.1): first account + opening
/// balance, reusing the accounts feature's own create path
/// (`accountsControllerProvider.createAccount`) so onboarding and the
/// Accounts screen share one source of truth for account creation.
///
/// Unlike the other Foundation-style steps, this one is NOT deferred to
/// [OnboardingController.commit]: tapping "Hisob qo'shish" writes the
/// account immediately. That also makes the step's skippability literal --
/// the shared "Keyingi"/"O'tkazib yuborish" controls in [OnboardingScreen]
/// simply move on without ever creating anything.
class AccountStep extends OnboardingStep {
  @override
  String get id => 'account';
  @override
  String get title => 'Birinchi hisobingiz';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      _AccountStepBody(controller: controller, title: title);
}

class _AccountStepBody extends ConsumerStatefulWidget {
  const _AccountStepBody({required this.controller, required this.title});

  final OnboardingController controller;
  final String title;

  @override
  ConsumerState<_AccountStepBody> createState() => _AccountStepBodyState();
}

class _AccountStepBodyState extends ConsumerState<_AccountStepBody> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  Money? _opening;
  AccountType _type = AccountType.cash;
  bool _saving = false;
  bool _created = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final currency = widget.controller.state.settings.primaryCurrency;
    setState(() => _saving = true);
    await ref.read(accountsControllerProvider.notifier).createAccount(
          name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
          type: _type,
          openingBalance: _opening ?? Money.zero(currency),
          icon: 'wallet',
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _created = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.controller.state.settings.primaryCurrency;
    return Padding(
      padding: const EdgeInsets.all(VeloraSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            "Bu bosqichni keyinroq ham to'ldirishingiz mumkin.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: VeloraSpacing.lg),
          TextField(
            key: const Key('onboarding_account_name'),
            controller: _nameCtrl,
            enabled: !_created,
            decoration: const InputDecoration(labelText: 'Hisob nomi'),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          VeloraMoneyField(
            key: const Key('onboarding_account_balance'),
            controller: _balanceCtrl,
            currency: currency,
            enabled: !_created,
            label: "Boshlang'ich balans",
            onChanged: (m) => setState(() => _opening = m),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final type in accountTypesInDisplayOrder)
                ChoiceChip(
                  key: Key('onboarding-account-type-${type.name}'),
                  label: Text(accountTypeLabel(type)),
                  selected: _type == type,
                  onSelected:
                      _created ? null : (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.lg),
          if (_created)
            const VeloraStatusBadge(
              key: Key('onboarding_account_created_badge'),
              color: VeloraColors.success,
              icon: Icons.check_circle,
              label: 'Hisob yaratildi',
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('onboarding_account_create_button'),
                onPressed: _saving ? null : _createAccount,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Hisob qo'shish"),
              ),
            ),
        ],
      ),
    );
  }
}
