import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

class AccountWithBalance {
  final Account account;
  final Money balance;
  const AccountWithBalance(this.account, this.balance);
}

class AccountsController extends AsyncNotifier<List<AccountWithBalance>> {
  @override
  Future<List<AccountWithBalance>> build() async {
    ref.watch(ledgerRevisionProvider);
    final accounts =
        await ref.watch(accountRepositoryProvider).list();
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    return [
      for (final a in accounts) AccountWithBalance(a, accountBalance(a, entries)),
    ];
  }

  Future<void> _invalidate() async {
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  }) async {
    await ref.read(accountRepositoryProvider).create(
        name: name, type: type, openingBalance: openingBalance, icon: icon);
    await _invalidate();
  }

  Future<void> rename(int id, String name) async {
    await ref.read(accountRepositoryProvider).rename(id, name);
    await _invalidate();
  }

  Future<void> archive(int id) async {
    await ref.read(accountRepositoryProvider).setArchived(id, true);
    await _invalidate();
  }

  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
  }) async {
    final r = await ref.read(ledgerRepositoryProvider).transfer(
        fromId: fromId, toId: toId, amount: amount, occurredAt: DateTime.now());
    if (r.isOk) await _invalidate();
    return r;
  }

  Future<void> adjust({
    required int accountId,
    required Money realBalance,
  }) async {
    await ref.read(ledgerRepositoryProvider).adjustBalance(
        accountId: accountId, realBalance: realBalance, occurredAt: DateTime.now());
    await _invalidate();
  }
}

final accountsControllerProvider =
    AsyncNotifierProvider<AccountsController, List<AccountWithBalance>>(
        AccountsController.new);
