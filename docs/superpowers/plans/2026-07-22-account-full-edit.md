# Kartalarni to'liq tahrirlash — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kartalar sahifasida kartaga bosilganda hisobning nomi, turi, byudjet roli va balansini bitta oynada to'liq tahrirlash imkoniyatini qo'shish.

**Architecture:** Mavjud yaratish oynasini (`account_edit_sheet.dart`) ikki rejimli (yaratish/tahrirlash) qilib kengaytiramiz. Kartaga bosish endi shu oynani tahrirlash rejimida ochadi. Repozitoriyga `setType`, kontrollerga bitta `edit(...)` diff-metodi qo'shiladi; endi ishlatilmaydigan `balance_adjust_sheet.dart` o'chiriladi.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), Drift (SQLite). Testlar: `flutter test --concurrency=1`.

## Global Constraints

- Money bilan hech qachon floating-point ishlatilmaydi; balansni matndan `parseMoneyInput` / `Money.tryParse` orqali o'qing, matnga `Money.formatNumber()` orqali yozing.
- Schema o'zgarishi **YO'Q** — `type`, `role`, `name` ustunlari allaqachon mavjud.
- Uzbekcha yorliqlar `account_labels.dart` dan olinadi (`accountTypeLabel`, `accountRoleLabel`, `accountTypesInDisplayOrder`, `accountRolesInDisplayOrder`).
- Balans faqat ledger `adjustBalance` orqali o'zgaradi (ochilish balansi bevosita qayta yozilmaydi).
- Test buyrug'i: `flutter test --concurrency=1 <path>`.

---

### Task 1: Repozitoriyga `setType` qo'shish

**Files:**
- Modify: `lib/data/accounts/account_repository.dart` (interfeys ~satr 8-23; Drift impl `setRole` yonida ~satr 75-79)
- Test: `test/data/accounts/account_repository_test.dart`

**Interfaces:**
- Consumes: mavjud `AccountRepository` abstrakt klassi, `DriftAccountRepository`, `AccountsTableCompanion`.
- Produces: `Future<void> setType(int id, AccountType type)` — `accounts_table` dagi `type` ustunini `type.name` bilan yozadi.

- [ ] **Step 1: Failing test yozish**

`test/data/accounts/account_repository_test.dart` faylida `setRole updates the stored role` testidan keyin qo'shing:

```dart
  test('setType updates the stored type', () async {
    final id = await repo.create(
        name: 'A',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'w');
    await repo.setType(id, AccountType.bankCard);
    expect((await repo.byId(id))!.type, AccountType.bankCard);
    // list() reads type too
    expect((await repo.list()).single.type, AccountType.bankCard);
  });
```

- [ ] **Step 2: Testni ishga tushirib, fail bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
Expected: FAIL — `The method 'setType' isn't defined for the type 'AccountRepository'` (kompilyatsiya xatosi).

- [ ] **Step 3: Interfeysga metodni qo'shish**

`lib/data/accounts/account_repository.dart` da abstrakt klassga, `Future<void> setRole(int id, AccountRole role);` satridan keyin qo'shing:

```dart
  Future<void> setType(int id, AccountType type);
```

- [ ] **Step 4: Drift implementatsiyasini qo'shish**

O'sha faylda `setRole` implementatsiyasidan keyin qo'shing:

```dart
  @override
  Future<void> setType(int id, AccountType type) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(type: Value(type.name)));
  }
```

- [ ] **Step 5: Testni ishga tushirib, pass bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
Expected: PASS (barcha testlar).

- [ ] **Step 6: Commit**

```bash
git add lib/data/accounts/account_repository.dart test/data/accounts/account_repository_test.dart
git commit -m "feat(accounts): add setType to account repository"
```

---

### Task 2: Kontrollerga `edit(...)` diff-metodi qo'shish

**Files:**
- Modify: `lib/features/accounts/accounts_controller.dart` (`adjust` metodidan keyin, ~satr 74-81)
- Test: `test/features/accounts/accounts_actions_test.dart`

**Interfaces:**
- Consumes: `accountRepositoryProvider` (`rename`, `setType`, `setRole`), `ledgerRepositoryProvider` (`adjustBalance`, `allEntries`), maxfiy `_invalidate()`, `AccountType`, `AccountRole`, `Money`.
- Produces:
  ```dart
  Future<void> edit({
    required int id,
    String? name,
    AccountType? type,
    AccountRole? role,
    Money? realBalance,
  });
  ```
  Faqat null bo'lmagan maydonlarni qo'llaydi; oxirida bir marta `_invalidate()`. `realBalance` berilsagina ledger'ga `adjustBalance` yozadi.

- [ ] **Step 1: Failing testlarni yozish**

`test/features/accounts/accounts_actions_test.dart` faylida, `adjust makes the balance equal the real value` testidan keyin (fayl oxiridagi `}` dan oldin) qo'shing:

```dart
  test('edit updates name, type and role together', () async {
    final c = makeContainer();
    final a = await add(c, 'Old', 1000000);
    await c.read(accountsControllerProvider.notifier).edit(
        id: a, name: 'New', type: AccountType.bankCard, role: AccountRole.reserve);
    final acc = (await c.read(accountsControllerProvider.future)).single.account;
    expect(acc.name, 'New');
    expect(acc.type, AccountType.bankCard);
    expect(acc.role, AccountRole.reserve);
  });

  test('edit with realBalance adjusts the balance to the real value', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    await c.read(accountsControllerProvider.notifier)
        .edit(id: a, realBalance: const Money(950000, uzs));
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.balance, const Money(950000, uzs));
  });

  test('edit without realBalance adds no ledger entry', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    final before =
        (await c.read(ledgerRepositoryProvider).allEntries()).length;
    await c.read(accountsControllerProvider.notifier).edit(id: a, name: 'B');
    final after =
        (await c.read(ledgerRepositoryProvider).allEntries()).length;
    expect(after, before);
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.balance, const Money(1000000, uzs));
  });
```

- [ ] **Step 2: Testni ishga tushirib, fail bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_actions_test.dart`
Expected: FAIL — `The method 'edit' isn't defined for the type 'AccountsController'`.

- [ ] **Step 3: `edit` metodini implementatsiya qilish**

`lib/features/accounts/accounts_controller.dart` da `adjust` metodidan keyin, klass ichida qo'shing:

```dart
  /// Applies a partial edit to an account. Only the non-null fields are
  /// written, so unchanged fields cause no DB write and an untouched balance
  /// creates no "Balans tuzatish" ledger entry. Invalidates once at the end.
  Future<void> edit({
    required int id,
    String? name,
    AccountType? type,
    AccountRole? role,
    Money? realBalance,
  }) async {
    final repo = ref.read(accountRepositoryProvider);
    if (name != null) await repo.rename(id, name);
    if (type != null) await repo.setType(id, type);
    if (role != null) await repo.setRole(id, role);
    if (realBalance != null) {
      await ref.read(ledgerRepositoryProvider).adjustBalance(
          accountId: id, realBalance: realBalance, occurredAt: DateTime.now());
    }
    await _invalidate();
  }
```

- [ ] **Step 4: Testni ishga tushirib, pass bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_actions_test.dart`
Expected: PASS (barcha testlar).

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/accounts_controller.dart test/features/accounts/accounts_actions_test.dart
git commit -m "feat(accounts): add edit() diff method to accounts controller"
```

---

### Task 3: Tahrirlash oynasi, kartaga bosish va tozalash

**Files:**
- Modify: `lib/features/accounts/account_edit_sheet.dart` (ikki rejim)
- Modify: `lib/features/accounts/accounts_screen.dart` (satr 8 import, satr 80-81 `onTap`)
- Delete: `lib/features/accounts/balance_adjust_sheet.dart`
- Test: `test/features/accounts/accounts_screen_test.dart` (satr 104-125 dagi testni yangilash + yangi test)

**Interfaces:**
- Consumes: `AccountsController.edit(...)` va `createAccount(...)` (Task 2), `accountsControllerProvider`, `settingsProvider`, `AccountWithBalance`, `Money.formatNumber()`, `account_labels.dart` yorliqlari.
- Produces: `Future<void> showAccountEditSheet(BuildContext context, WidgetRef ref, {int? accountId})` — `accountId == null` yaratish, aks holda tahrirlash rejimi.

- [ ] **Step 1: Widget testlarini yangilash/yozish**

`test/features/accounts/accounts_screen_test.dart` da mavjud testni (satr 104-125, `tapping an account tile opens the balance-adjust sheet`) TO'LIQ shu ikki test bilan almashtiring:

```dart
  testWidgets('tapping an account tile opens the full edit sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs), icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Naqd'));
    await tester.pumpAndSettle();

    // Edit-mode title, and the balance field prefilled with the current
    // balance (grouped, symbol-less — Money.formatNumber()).
    expect(find.text('Hisobni tahrirlash'), findsOneWidget);
    expect(
        find.text(const Money(500000, CurrencyRegistry.uzs).formatNumber()),
        findsOneWidget);
  });

  testWidgets('editing an account name from the tile updates the list',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs), icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Naqd'));
    await tester.pumpAndSettle();

    // The name field is the first TextField in the sheet.
    await tester.enterText(find.byType(TextField).first, 'Karta');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Karta'), findsOneWidget);
    expect(find.text('Naqd'), findsNothing);
  });
```

- [ ] **Step 2: Testni ishga tushirib, fail bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_screen_test.dart`
Expected: FAIL — `Hisobni tahrirlash` topilmaydi (kartaga bosish hali balans oynasini ochyapti).

- [ ] **Step 3: `account_edit_sheet.dart` ni ikki rejimli qilish**

`lib/features/accounts/account_edit_sheet.dart` faylini TO'LIQ shu bilan almashtiring:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'account_labels.dart';
import 'accounts_controller.dart';

/// Opens the account sheet. With no [accountId] it creates a new account;
/// with an [accountId] it edits that account (name, type, role, balance).
Future<void> showAccountEditSheet(
  BuildContext context,
  WidgetRef ref, {
  int? accountId,
}) async {
  final settings = await ref.read(settingsProvider.future);
  AccountWithBalance? existing;
  if (accountId != null) {
    final list = await ref.read(accountsControllerProvider.future);
    for (final e in list) {
      if (e.account.id == accountId) {
        existing = e;
        break;
      }
    }
  }
  final currency = existing?.account.currency ?? settings.primaryCurrency;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AccountEditSheetBody(currency: currency, existing: existing),
  );
}

class _AccountEditSheetBody extends ConsumerStatefulWidget {
  const _AccountEditSheetBody({required this.currency, this.existing});

  final Currency currency;
  final AccountWithBalance? existing;

  @override
  ConsumerState<_AccountEditSheetBody> createState() =>
      _AccountEditSheetBodyState();
}

class _AccountEditSheetBodyState extends ConsumerState<_AccountEditSheetBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  Money? _balance;
  AccountType _type = AccountType.cash;
  AccountRole _role = AccountRole.spending;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.account.name ?? '');
    // In edit mode prefill the balance field with the current balance, using
    // the symbol-less grouped form the money formatter round-trips.
    _balanceCtrl = TextEditingController(
        text: existing != null ? existing.balance.formatNumber() : '');
    if (existing != null) {
      _type = existing.account.type;
      _role = existing.account.role;
      _balance = existing.balance;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(accountsControllerProvider.notifier);
    if (_isEdit) {
      final existing = widget.existing!;
      final acc = existing.account;
      final name = _nameCtrl.text.trim();
      // Only pass fields that actually changed. An empty name is treated as
      // "unchanged" so the user can't blank the account name.
      await notifier.edit(
        id: acc.id,
        name: (name.isNotEmpty && name != acc.name) ? name : null,
        type: _type != acc.type ? _type : null,
        role: _role != acc.role ? _role : null,
        realBalance:
            (_balance != null && _balance != existing.balance) ? _balance : null,
      );
    } else {
      await notifier.createAccount(
          name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
          type: _type,
          openingBalance: _balance ?? Money.zero(widget.currency),
          icon: 'wallet',
          role: _role);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: _isEdit ? 'Hisobni tahrirlash' : 'Yangi hisob',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nomi'),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          VeloraMoneyField(
            controller: _balanceCtrl,
            currency: widget.currency,
            label: _isEdit ? 'Balans' : 'Boshlang\'ich balans',
            onChanged: (m) => setState(() => _balance = m),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final type in accountTypesInDisplayOrder)
                ChoiceChip(
                  key: Key('account-type-${type.name}'),
                  label: Text(accountTypeLabel(type)),
                  selected: _type == type,
                  // Selection is shown by the chip's fill, matching the
                  // mockup. Suppress the leading checkmark: it would widen
                  // the selected chip and reflow the Wrap, making chips jump
                  // rows as the user switches types.
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.lg),
          const Text('Byudjet roli'),
          const SizedBox(height: VeloraSpacing.sm),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final role in accountRolesInDisplayOrder)
                ChoiceChip(
                  key: Key('account-role-${role.name}'),
                  label: Text(accountRoleLabel(role)),
                  selected: _role == role,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            accountRoleHelper(_role),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Saqlash',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    );
  }
}
```

- [ ] **Step 4: Kartaga bosishni tahrirlash oynasiga ulash**

`lib/features/accounts/accounts_screen.dart` da:

satr 8 dagi importni o'chiring:
```dart
import 'balance_adjust_sheet.dart';
```

satr 80-81 dagi `onTap` ni almashtiring:
```dart
                    onTap: () => showAccountEditSheet(context, ref,
                        accountId: it.account.id),
```

- [ ] **Step 5: Ishlatilmaydigan balans oynasini o'chirish**

```bash
git rm lib/features/accounts/balance_adjust_sheet.dart
```

- [ ] **Step 6: Testni ishga tushirib, pass bo'lishini tekshirish**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_screen_test.dart`
Expected: PASS (barcha testlar).

- [ ] **Step 7: Butun to'plamni ishga tushirib, regressiya yo'qligini tekshirish**

Run: `flutter test --concurrency=1`
Expected: PASS. (Eslatma: memory'da qayd etilgan ba'zi to'liq-ekran goldenlari bu muhitda oldindan mavjud/environmental sabablarga ko'ra fail bo'lishi mumkin — bular bu ish bilan bog'liq emas. `balance_adjust_sheet` faqat `accounts_screen.dart` da ishlatilgani uchun uni o'chirish boshqa testlarni buzmasligi kerak.)

- [ ] **Step 8: `flutter analyze` bilan tekshirish**

Run: `flutter analyze`
Expected: `balance_adjust_sheet.dart` ga bog'liq "unused import"/"not found" xatolari yo'q; yangi kod bo'yicha ogohlantirish yo'q.

- [ ] **Step 9: Commit**

```bash
git add lib/features/accounts/account_edit_sheet.dart lib/features/accounts/accounts_screen.dart test/features/accounts/accounts_screen_test.dart
git commit -m "feat(accounts): full account edit on tile tap; remove balance-adjust sheet"
```

---

## Self-Review

- **Spec coverage:**
  - Ikki rejimli sheet → Task 3. Tahrirlash prefill (nom/tur/rol/balans) → Task 3 Step 3 `initState`. Faqat o'zgargan maydon yoziladi → Task 2 `edit` + Task 3 `_save` diff logikasi. Balans semantikasi (tuzatish yozuvi, tegilmasa yozuv yo'q) → Task 2 testlari + `edit`. Kartaga bosish → Task 3 Step 4. `setType` → Task 1. Kontroller `edit` → Task 2. `balance_adjust_sheet.dart` o'chirish → Task 3 Step 5. Testlar → har uch Task. Schema o'zgarishi yo'q → tasdiqlangan.
- **Placeholder scan:** Yo'q — har bir kod qadami to'liq kod bilan berilgan.
- **Type consistency:** `edit({id, name?, type?, role?, realBalance?})` Task 2 da e'lon qilingan va Task 3 da xuddi shu imzo bilan chaqirilgan. `setType(int, AccountType)` Task 1 da e'lon qilingan, Task 2 `edit` da ishlatilgan. `Money.formatNumber()` (mavjud) prefill uchun, `AccountWithBalance.balance`/`.account` (mavjud) ishlatilgan. `showAccountEditSheet(..., {int? accountId})` Task 3 da e'lon, mavjud `FloatingActionButton` va bo'sh-holat tugmasi `accountId`siz chaqiradi (yaratish rejimi — o'zgarmaydi).
