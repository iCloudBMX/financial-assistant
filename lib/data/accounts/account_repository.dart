// lib/data/accounts/account_repository.dart
import 'package:drift/drift.dart';
import '../../core/ledger/account.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';

abstract class AccountRepository {
  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  });
  Future<void> rename(int id, String name);
  Future<void> setIcon(int id, String icon);
  Future<void> setArchived(int id, bool archived);
  Future<void> reorder(List<int> orderedIds);
  Future<List<Account>> list({bool includeArchived = false});
  Future<Account?> byId(int id);
}

class DriftAccountRepository implements AccountRepository {
  final AppDatabase db;
  DriftAccountRepository(this.db);

  Account _map(dynamic r) => Account(
        id: r.id as int,
        name: r.name as String,
        type: AccountType.values.byName(r.type as String),
        openingBalance: Money(
          r.openingBalanceMinor as int,
          CurrencyRegistry.byCode(r.currencyCode as String),
        ),
        icon: r.icon as String,
        archived: r.archived as bool,
      );

  @override
  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  }) {
    return db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: name,
            type: type.name,
            openingBalanceMinor: Value(openingBalance.minorUnits),
            currencyCode: Value(openingBalance.currency.code),
            icon: Value(icon),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> rename(int id, String name) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(name: Value(name)));
  }

  @override
  Future<void> setIcon(int id, String icon) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(icon: Value(icon)));
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(archived: Value(archived)));
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.accountsTable)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(AccountsTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<List<Account>> list({bool includeArchived = false}) async {
    final q = db.select(db.accountsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  @override
  Future<Account?> byId(int id) async {
    final row = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }
}
