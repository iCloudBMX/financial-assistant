import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger/ledger_entry.dart';
import '../../core/theme/velora_tokens.dart';
import '../../core/transactions/transaction_filter.dart';
import '../../ui/components/velora_button.dart'; // exports VeloraPrimaryButton
import '../accounts/accounts_controller.dart';
import 'transactions_filter_provider.dart';

/// A compact, content-height bottom sheet for the filters: a grabber handle,
/// a title, a scrollable body capped at ~55% of the screen, and a fixed action
/// area. Unlike [VeloraSheetScaffold] (which fills the whole screen via a
/// Scaffold + Expanded), this wraps its content so a short sheet like Davr
/// only takes the space it needs.
class _FilterSheetShell extends StatelessWidget {
  const _FilterSheetShell({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final Widget body;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VeloraRadii.sheet),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: VeloraSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VeloraColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(VeloraSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: VeloraSpacing.lg),
                    // Cap the body so a long list scrolls instead of pushing the
                    // sheet full-screen; short content keeps the sheet compact.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: media.size.height * 0.55,
                      ),
                      child: SingleChildScrollView(child: body),
                    ),
                    const SizedBox(height: VeloraSpacing.lg),
                    actions,
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

/// The three "O'tkazma"-grouped operation choices offered to the user.
const _typeChoices = <({String label, Set<LedgerEntryType> types})>[
  (label: 'Kirim', types: {LedgerEntryType.income}),
  (label: 'Chiqim', types: {LedgerEntryType.expense}),
  (
    label: "O'tkazma",
    types: {LedgerEntryType.transferOut, LedgerEntryType.transferIn}
  ),
];

Future<void> showPeriodFilterSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PeriodSheet(initial: current),
  );
}

Future<void> showAccountFilterSheet(BuildContext context, WidgetRef ref) async {
  final accounts = await ref.read(accountsControllerProvider.future);
  if (!context.mounted) return;
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AccountSheet(
      accounts: accounts,
      initial: current.accountIds,
    ),
  );
}

Future<void> showTypeFilterSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TypeSheet(initial: current.types),
  );
}

class _PeriodSheet extends ConsumerStatefulWidget {
  const _PeriodSheet({required this.initial});
  final TransactionFilter initial;
  @override
  ConsumerState<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends ConsumerState<_PeriodSheet> {
  DateTime? _start;
  DateTime? _end;
  String? _label;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.period?.start;
    _end = widget.initial.period?.end;
    _label = widget.initial.periodLabel;
  }

  void _preset(String label, DateTimeRange range) {
    setState(() {
      _start = range.start;
      _end = range.end;
      _label = label;
    });
  }

  String _fmt(DateTime? d) => d == null
      ? 'KK.OO.YYYY'
      : '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pick({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _label = null; // a manual edit is a custom range
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <({String label, DateTimeRange range})>[
      (label: 'Bugun', range: DateTimeRange(start: today, end: today)),
      (
        label: 'Kecha',
        range: DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today.subtract(const Duration(days: 1)),
        )
      ),
      (
        label: "O'tgan hafta",
        range: DateTimeRange(
            start: today.subtract(const Duration(days: 7)), end: today)
      ),
      (
        label: "O'tgan oy",
        range: DateTimeRange(
            start: DateTime(now.year, now.month - 1, 1),
            end: DateTime(now.year, now.month, 0))
      ),
      (label: 'Bu oy', range: currentMonthFilter(now).period!),
    ];

    return _FilterSheetShell(
      title: 'Davr',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                    label: 'Sanadan',
                    value: _fmt(_start),
                    onTap: () => _pick(isStart: true)),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: _DateField(
                    label: 'Sanagacha',
                    value: _fmt(_end),
                    onTap: () => _pick(isStart: false)),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _label == p.label,
                  onSelected: (_) => _preset(p.label, p.range),
                ),
            ],
          ),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).update(
                    (f) => f.copyWith(clearPeriod: true));
                Navigator.of(context).pop();
              },
              child: const Text("O'chirish"),
            ),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: VeloraPrimaryButton(
              label: "Ko'rsatish",
              onPressed: () {
                if (_start != null && _end != null) {
                  final s = _start!;
                  final e = _end!;
                  final range = s.isAfter(e)
                      ? DateTimeRange(start: e, end: s)
                      : DateTimeRange(start: s, end: e);
                  ref.read(transactionFilterProvider.notifier).update(
                        (f) => f.copyWith(
                          period: range,
                          periodLabel: _label ??
                              '${_fmt(range.start)}–${_fmt(range.end)}',
                        ),
                      );
                }
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: VeloraColors.muted)),
        const SizedBox(height: VeloraSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VeloraRadii.control),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: VeloraSpacing.md, vertical: VeloraSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VeloraRadii.control),
              border: Border.all(color: VeloraColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
                const Icon(Icons.calendar_today,
                    size: 18, color: VeloraColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.accounts, required this.initial});
  final List<AccountWithBalance> accounts;
  final Set<int> initial;
  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final allIds = {for (final a in widget.accounts) a.account.id};
    final allSelected = _selected.isEmpty || _selected.containsAll(allIds);
    return _FilterSheetShell(
      title: 'Kartalar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: allSelected,
            title: const Text('Barcha kartalar'),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => setState(() => _selected.clear()),
          ),
          for (final a in widget.accounts)
            CheckboxListTile(
              value: _selected.contains(a.account.id),
              title: Text(a.account.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(a.account.id);
                } else {
                  _selected.remove(a.account.id);
                }
              }),
            ),
        ],
      ),
      actions: VeloraPrimaryButton(
        label: "Ko'rsatish",
        onPressed: () {
          final allIds = {for (final a in widget.accounts) a.account.id};
          // All-selected and none-selected both mean "no restriction" —
          // normalize to the empty set so the chip reads as un-narrowed.
          final committed =
              (_selected.isEmpty || _selected.containsAll(allIds))
                  ? <int>{}
                  : {..._selected};
          ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(accountIds: committed));
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _TypeSheet extends ConsumerStatefulWidget {
  const _TypeSheet({required this.initial});
  final Set<LedgerEntryType> initial;
  @override
  ConsumerState<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends ConsumerState<_TypeSheet> {
  late Set<LedgerEntryType> _selected;

  static Set<LedgerEntryType> get _allTypes =>
      {for (final c in _typeChoices) ...c.types};

  @override
  void initState() {
    super.initState();
    _selected =
        widget.initial.isEmpty ? {..._allTypes} : {...widget.initial};
  }

  bool _isOn(Set<LedgerEntryType> group) => group.every(_selected.contains);

  @override
  Widget build(BuildContext context) {
    return _FilterSheetShell(
      title: 'Operatsiya turi',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in _typeChoices)
            CheckboxListTile(
              value: _isOn(choice.types),
              title: Text(choice.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.addAll(choice.types);
                } else {
                  _selected.removeAll(choice.types);
                }
              }),
            ),
        ],
      ),
      actions: VeloraPrimaryButton(
        label: "Ko'rsatish",
        onPressed: () {
          // All-selected and none-selected both mean "no restriction" —
          // normalize to the empty set so the chip reads as un-narrowed.
          final committed =
              (_selected.isEmpty || _selected.containsAll(_allTypes))
                  ? <LedgerEntryType>{}
                  : {..._selected};
          ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(types: committed));
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
