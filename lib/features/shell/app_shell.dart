import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../budgets/budgets_screen.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../transactions/transactions_screen.dart';
import 'placeholder_tab.dart';

class AppShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 5);

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index = widget.initialIndex;

  static const _tabs = <Widget>[
    KeyedSubtree(key: PageStorageKey('home-tab'), child: HomeScreen()),
    KeyedSubtree(
      key: PageStorageKey('history-tab'),
      child: TransactionsScreen(),
    ),
    KeyedSubtree(key: PageStorageKey('plan-tab'), child: BudgetsScreen()),
    KeyedSubtree(key: PageStorageKey('goals-tab'), child: GoalsScreen()),
    KeyedSubtree(
      key: PageStorageKey('reports-tab'),
      child: PlaceholderTab(title: 'Tahlil'),
    ),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Bugun'),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      label: 'Tarix',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_tree_outlined),
      label: 'Reja',
    ),
    NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Maqsad'),
    NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Tahlil'),
  ];

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(index: _index, children: _tabs),
    ),
    // Keep the global action away from feature-local trailing FABs (Goals
    // currently has one) so both actions remain reachable.
    floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('global-expense-action'),
      onPressed: () => showExpenseEntrySheet(context, ref),
      icon: const Icon(Icons.remove),
      label: const Text('Chiqim'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: _destinations,
    ),
  );
}
