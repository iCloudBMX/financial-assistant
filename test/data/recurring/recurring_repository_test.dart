// test/data/recurring/recurring_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/data/recurring/recurring_repository.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  group('nextRecurringDate', () {
    test('monthly rolls to the anchor day of the next month', () {
      expect(nextRecurringDate(DateTime(2026, 7, 5), IntervalKind.monthly, 5),
          DateTime(2026, 8, 5));
    });
    test('monthly clamps a too-large anchor day to month end', () {
      expect(nextRecurringDate(DateTime(2026, 1, 31), IntervalKind.monthly, 31),
          DateTime(2026, 2, 28));
    });
    test('weekly advances seven days', () {
      expect(nextRecurringDate(DateTime(2026, 7, 5), IntervalKind.weekly, 7),
          DateTime(2026, 7, 12));
    });
  });

  group('repository', () {
    late AppDatabase db;
    late RecurringIncomeRepository repo;
    late AccountRepository accountRepo;
    late int accountId;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftRecurringIncomeRepository(db);
      accountRepo = DriftAccountRepository(db);
      accountId = await accountRepo.create(
        name: 'Test Account',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'wallet'
      );
    });
    tearDown(() => db.close());

    test('due plans are those with nextDueAt at or before now', () async {
      await repo.create(accountId: accountId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));
      await repo.create(accountId: accountId, amount: const Money(1000000, uzs), incomeType: IncomeType.bonus, intervalKind: IntervalKind.monthly, anchorDay: 20, nextDueAt: DateTime(2026, 8, 20));
      final due = await repo.duePlans(DateTime(2026, 7, 10));
      expect(due.length, 1);
      expect(due.single.amount, const Money(5000000, uzs));
    });

    test('markConfirmed advances nextDueAt to the next occurrence', () async {
      final id = await repo.create(accountId: accountId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));
      await repo.markConfirmed(id);
      final due = await repo.duePlans(DateTime(2026, 7, 10));
      expect(due, isEmpty); // now due Aug 5
      final active = await repo.listActive();
      expect(active.single.nextDueAt, DateTime(2026, 8, 5));
    });

    test('postponeTo sets nextDueAt to the given date without advancing a period',
        () async {
      final id = await repo.create(accountId: accountId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));
      await repo.postponeTo(id, DateTime(2026, 7, 20));
      final active = await repo.listActive();
      expect(active.single.nextDueAt, DateTime(2026, 7, 20)); // exact chosen date
      expect(active.single.anchorDay, 5); // anchor untouched
    });
  });
}
