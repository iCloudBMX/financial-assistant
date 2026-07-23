import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/reports/period_summary.dart';
import '../data/categories/category_model.dart';
import '../features/month_close/month_close_data.dart';
import 'app_providers.dart';
import 'reports_providers.dart';

/// Non-null once there is an elapsed, unclosed period to show the §16.1
/// close-out CTA for. Null means: nothing to close, don't show the banner.
final monthCloseProvider = FutureProvider<MonthCloseData?>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final period = closeablePeriod(
      DateTime.now(), settings.periodStartDay, settings.lastClosedPeriodStart);
  if (period == null) return null;

  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final categories = await ref.watch(categoriesProvider.future);
  final currency = settings.primaryCurrency;
  final mandatoryIds = {
    for (final c in categories)
      if (c.kind == CategoryKind.mandatory) c.id
  };

  final summary = buildMonthlySummary(
      accounts: accounts,
      entries: entries,
      mandatoryCategoryIds: mandatoryIds,
      period: period,
      currency: currency);
  final goalAllocated = await goalAllocatedInPeriod(ref, period, currency);

  return MonthCloseData(
      period: period, summary: summary, goalAllocated: goalAllocated);
});

/// Marks [periodStart] as closed: persists `lastClosedPeriodStart` and
/// invalidates the read-side providers that key off it.
final closePeriodProvider =
    Provider<Future<void> Function(DateTime)>((ref) => (periodStart) async {
  final repo = ref.read(settingsRepositoryProvider);
  final current = await repo.read();
  await repo.write(current.copyWith(lastClosedPeriodStart: periodStart));
  ref.invalidate(settingsProvider);
  ref.read(ledgerRevisionProvider.notifier).state++;
});
