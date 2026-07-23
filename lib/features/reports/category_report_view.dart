import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/reports_providers.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';

/// One category's actual-spend row for the Reports ▸ Kategoriya tab.
/// Deliberately has no planned/remaining/deviation fields — category
/// budgets were removed from the app (see spec Conflict A); this is
/// actuals-only.
class CategoryReportRow {
  final int categoryId;
  final String name;
  final String icon;
  final Money spent;
  final int shareBp;
  final Money prevSpent;
  const CategoryReportRow({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.spent,
    required this.shareBp,
    required this.prevSpent,
  });
}

/// Basis points (1/100 of a percent) that [part] is of [total], rounded to
/// the nearest integer. Returns 0 when [total] is zero or negative rather
/// than dividing by zero.
int shareBp(Money part, Money total) {
  if (total.minorUnits <= 0) return 0;
  return ((part.minorUnits * 10000) / total.minorUnits).round();
}

/// The Kategoriya (category) tab: actual spend per category this period,
/// its share of total expense, and the trend vs the previous period.
class CategoryReportView extends ConsumerWidget {
  const CategoryReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(categoryReportProvider);
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VeloraErrorState(
        message: 'Xatolik yuz berdi',
        onRetry: () => ref.invalidate(categoryReportProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const VeloraEmptyState(
            icon: Icons.pie_chart_outline,
            title: "Xarajat yo'q",
            message: 'Bu davrda kategoriya bo\'yicha xarajat qayd etilmagan.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows) ...[
              _CategoryRowCard(row: row),
              const SizedBox(height: VeloraSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryRowCard extends StatelessWidget {
  const _CategoryRowCard({required this.row});

  final CategoryReportRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = row.spent.subtract(row.prevSpent);
    final trendUp = diff.minorUnits > 0;
    final trendFlat = diff.minorUnits == 0;
    return VeloraCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: VeloraColors.apricotTint,
            foregroundColor: VeloraColors.plum,
            child: Icon(categoryIcon(row.icon)),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: VeloraSpacing.xs),
                Text('${(row.shareBp / 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: VeloraColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(row.spent.format(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: VeloraSpacing.xs),
              if (!trendFlat)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: trendUp
                          ? VeloraColors.critical
                          : VeloraColors.success,
                    ),
                    Text(diff.abs().format(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: trendUp
                              ? VeloraColors.critical
                              : VeloraColors.success,
                        )),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on Money {
  Money abs() => isNegative ? negate() : this;
}
