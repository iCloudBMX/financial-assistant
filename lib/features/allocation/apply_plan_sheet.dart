import 'package:flutter/material.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_sheet.dart';

/// Confirm sheet shown before transfers run: each destination + amount, what
/// stays on the source, and any shortfall (colour + icon + text, never colour
/// alone). Returns true to execute.
Future<bool?> showApplyPlanSheet(
  BuildContext context, {
  required PlanApplyResult result,
  required Map<int, String> destNames,
  required String sourceName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApplyPlanBody(
      result: result,
      destNames: destNames,
      sourceName: sourceName,
    ),
  );
}

class _ApplyPlanBody extends StatelessWidget {
  const _ApplyPlanBody({
    required this.result,
    required this.destNames,
    required this.sourceName,
  });
  final PlanApplyResult result;
  final Map<int, String> destNames;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VeloraSheetScaffold(
      title: 'Rejani qo\'llash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
              child: Text('Ko\'chiriladigan mablag\' yo\'q.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: VeloraColors.muted)),
            )
          else
            for (final t in result.transfers)
              Padding(
                padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(destNames[t.destinationAccountId] ?? 'Karta',
                          style: theme.textTheme.bodyLarge),
                    ),
                    Text('+${t.amount.format()}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: VeloraColors.success,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          const Divider(height: VeloraSpacing.lg * 2, color: VeloraColors.line),
          Row(
            children: [
              Expanded(
                child: Text('$sourceName\'da qoladi',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: VeloraColors.muted)),
              ),
              Text(result.sourceRemaining.format(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          if (result.hasShortfall) ...[
            const SizedBox(height: VeloraSpacing.md),
            Container(
              padding: const EdgeInsets.all(VeloraSpacing.md),
              decoration: BoxDecoration(
                color: VeloraColors.critical.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: VeloraColors.critical),
                  const SizedBox(width: VeloraSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ba\'zi qatorlar to\'liq to\'lanmadi — kartada mablag\' yetarli emas.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.critical),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Bajarish',
        onPressed: result.transfers.isEmpty
            ? null
            : () => Navigator.of(context).pop(true),
      ),
    );
  }
}
