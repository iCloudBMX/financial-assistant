// §6.9/§13.3: mortgage payment sheet — the user types the principal (tani) and
// interest (foiz) portions and picks the card the payment is drawn from.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/mortgage/mortgage_model.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';
import 'mortgage_controller.dart';

Future<void> showMortgagePaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MortgagePaymentSheet(mortgageId: mortgageId),
  );
}

class MortgagePaymentSheet extends ConsumerStatefulWidget {
  final int mortgageId;
  const MortgagePaymentSheet({super.key, required this.mortgageId});
  @override
  ConsumerState<MortgagePaymentSheet> createState() => _MortgagePaymentSheetState();
}

class _MortgagePaymentSheetState extends ConsumerState<MortgagePaymentSheet> {
  final _principal = TextEditingController();
  final _interest = TextEditingController();
  int? _accountId;
  String? _error;
  bool _saving = false;
  static const _uzs = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    for (final c in [_principal, _interest]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_principal, _interest]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(
      int principalMinor, int interestMinor, int accountId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // A `finally` always clears `_saving` so a throwing repository call can
    // never leave Save permanently disabled; typed failures map through
    // `userMessageFor`, raw exceptions get a plain-language fallback.
    var popped = false;
    try {
      final res = await ref.read(mortgageControllerProvider).recordPayment(
            mortgageId: widget.mortgageId,
            // Total is simply the sum of the two typed portions — the user
            // enters principal (tani) and interest (foiz) directly.
            split: MortgagePaymentSplit(
              totalMinor: principalMinor + interestMinor,
              principalMinor: principalMinor,
              interestMinor: interestMinor,
            ),
            accountId: accountId,
          );
      if (!mounted) return;
      res.when(
        ok: (_) => popped = true,
        err: (f) => setState(() => _error = userMessageFor(f)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Saqlashda kutilmagan xatolik yuz berdi.');
      }
    } finally {
      // Skip the setState when we're about to pop — the widget is on its way
      // out and there is no field left to re-enable.
      if (mounted && !popped) setState(() => _saving = false);
    }
    if (popped && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final principalMinor =
        (Money.tryParse(_principal.text, _uzs) ?? Money.zero(_uzs)).minorUnits;
    final interestMinor =
        (Money.tryParse(_interest.text, _uzs) ?? Money.zero(_uzs)).minorUnits;
    final totalMinor = principalMinor + interestMinor;
    final accountsAsync = ref.watch(accountsControllerProvider);
    final balances = {
      for (final a in (accountsAsync.value ?? const <AccountWithBalance>[]))
        a.account.id: a.balance.minorUnits,
    };
    final selectedBalance = _accountId == null ? null : balances[_accountId];
    // The payment can't draw more than the chosen card holds.
    final exceedsBalance =
        selectedBalance != null && totalMinor > selectedBalance;
    final canSave =
        totalMinor > 0 && _accountId != null && !exceedsBalance && !_saving;

    return VeloraSheetScaffold(
      title: 'To\'lov kiritish',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SplitCard(
            tint: VeloraColors.plumTint,
            iconTileColor: VeloraColors.plum,
            icon: Icons.home_outlined,
            title: 'Asosiy qarzga (tani)',
            subtitle: 'Qarz qoldig\'ini kamaytiradi',
            field: VeloraMoneyField(
              key: const Key('payment-principal'),
              controller: _principal,
              currency: _uzs,
              label: 'Miqdor',
              autofocus: true,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          _SplitCard(
            tint: VeloraColors.apricotTint,
            iconTileColor: VeloraColors.apricot,
            icon: Icons.percent,
            title: 'Foiz to‘lovi',
            subtitle: 'Qarz qoldig\'ini kamaytirmaydi',
            field: VeloraMoneyField(
              key: const Key('payment-interest'),
              controller: _interest,
              currency: _uzs,
              label: 'Miqdor',
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          _EquationBar(
            color: VeloraColors.plum,
            icon: Icons.summarize_outlined,
            title: 'Umumiy to\'lov',
            trailing: Money(totalMinor, _uzs).format(),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Text('Qaysi kartadan?', style: theme.textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.sm),
          accountsAsync.when(
            data: (list) {
              // Default to the first card (parity with the old silent
              // accounts.first), but let the user swipe/tap to another.
              if (_accountId == null && list.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _accountId = list.first.account.id);
                });
              }
              return AccountCardPicker(
                accounts: [for (final a in list) a.account],
                availableBalances: {
                  for (final a in list) a.account.id: a.balance,
                },
                selectedId: _accountId,
                onSelected: (id) => setState(() => _accountId = id),
              );
            },
            loading: () => const SizedBox(height: 116),
            error: (_, _) => const Text('Hisoblarni yuklab bo\'lmadi'),
          ),
          if (exceedsBalance) ...[
            const SizedBox(height: VeloraSpacing.sm),
            const _EquationBar(
              color: VeloraColors.critical,
              icon: Icons.error_outline,
              title: 'Kartada yetarli mablag\' yo\'q',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: VeloraSpacing.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      primaryAction: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          key: const Key('payment-save'),
          style: FilledButton.styleFrom(
            backgroundColor: VeloraColors.coral,
            foregroundColor: Colors.white,
          ),
          onPressed: canSave
              ? () => _save(principalMinor, interestMinor, _accountId!)
              : null,
          child: const Text('Saqlash'),
        ),
      ),
    );
  }
}

/// One explicit split component (§6.9): a tinted card with an icon tile, the
/// portion name, the always-on "reduces / does not reduce debt" helper line,
/// and either the derived value (Auto) or an editable field (Manual).
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.tint,
    required this.iconTileColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.field,
  });

  final Color tint;
  final Color iconTileColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconTileColor,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: VeloraSpacing.xs),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: VeloraColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          field,
        ],
      ),
    );
  }
}

/// The live balance line (§6.9): a tinted bar that turns green when the split
/// balances to the total and critical when it does not — the plain-language
/// half of the "save disabled until balanced" contract.
class _EquationBar extends StatelessWidget {
  const _EquationBar({
    required this.color,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.md,
        vertical: VeloraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(
            child: Text(title, style: theme.textTheme.labelLarge),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VeloraSpacing.sm),
            Text(
              trailing!,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}
