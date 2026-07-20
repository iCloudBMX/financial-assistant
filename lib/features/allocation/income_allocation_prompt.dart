import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import 'allocate_sheet.dart';
import 'allocation_controller.dart';
import 'variable_budget_offer.dart';

/// §7.2: after an income is saved, offer allocate-now / later / apply-template.
Future<void> showAllocationChoice(
  BuildContext context,
  WidgetRef ref, {
  required int incomeId,
  required Money amount,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllocationChoiceSheet(amount: amount),
  );

  if (choice == 'now' && context.mounted) {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AllocateSheet(incomeId: incomeId, income: amount),
    );
  } else if (choice == 'apply') {
    final preview =
        await ref.read(allocationControllerProvider).preview(amount);
    final confirmResult = await ref
        .read(allocationControllerProvider)
        .confirm(incomeId, preview.perBucket);
    if (!context.mounted) return;
    if (!confirmResult.isOk) {
      confirmResult.when(
        ok: (_) {},
        err: (f) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessageFor(f)))),
      );
      return;
    }
    await maybeOfferVariableBudgetUpdate(context, ref, preview.perBucket);
  }
  // 'later' / dismissed: leave the income undistributed.
}

/// The "income saved · next step" chooser from the money-flow mockups: a
/// success header with the accepted amount, then a card list whose primary
/// (coral) choice is "allocate now". Each card pops the same string
/// (`now`/`apply`/`later`) the caller already branches on.
class _AllocationChoiceSheet extends StatelessWidget {
  const _AllocationChoiceSheet({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VeloraRadii.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            VeloraSpacing.lg,
            VeloraSpacing.md,
            VeloraSpacing.lg,
            VeloraSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: VeloraColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VeloraColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: const Icon(Icons.check_rounded,
                    color: VeloraColors.success, size: 26),
              ),
              const SizedBox(height: VeloraSpacing.md),
              Text('${amount.format()} qabul qilindi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: VeloraSpacing.xs),
              Text('Keyingi qadamni tanlang',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: VeloraColors.muted)),
              const SizedBox(height: VeloraSpacing.lg),
              _ChoiceCard(
                icon: Icons.north_east,
                title: 'Hozir taqsimlash',
                subtitle:
                    'Majburiy xarajat, erkin budjet, maqsad va ipotekaga ajrating',
                primary: true,
                onTap: () => Navigator.pop(context, 'now'),
              ),
              const SizedBox(height: VeloraSpacing.sm),
              _ChoiceCard(
                icon: Icons.playlist_add_check,
                title: 'Rejani qo‘llash',
                subtitle:
                    'Andozadagi taqsimotni to‘g‘ridan-to‘g‘ri qo‘llash',
                onTap: () => Navigator.pop(context, 'apply'),
              ),
              const SizedBox(height: VeloraSpacing.sm),
              _ChoiceCard(
                icon: Icons.schedule,
                title: 'Keyinroq',
                subtitle:
                    'Dashboard’da taqsimlanmagan mablag‘ sifatida turadi',
                onTap: () => Navigator.pop(context, 'later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(VeloraRadii.card);
    final Color fill = primary ? VeloraColors.coralTint : theme.colorScheme.surfaceContainerLowest;
    final Color glyphFill = primary ? VeloraColors.coral : VeloraColors.plumTint;
    final Color glyphFg = primary ? Colors.white : VeloraColors.plum;
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
            color: primary ? VeloraColors.coral.withValues(alpha: 0.4) : VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(VeloraSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: glyphFill,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(icon, color: glyphFg, size: 20),
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
        ),
      ),
    );
  }
}
