import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../budgets/budgets_screen.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../transactions/transactions_screen.dart';
import 'placeholder_tab.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    GoalsScreen(),
    PlaceholderTab(title: 'Hisobotlar'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _tabs[_index]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showExpenseEntrySheet(context, ref),
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Bosh'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), label: 'Tranzaksiya'),
            NavigationDestination(
                icon: Icon(Icons.pie_chart_outline), label: 'Taqsimlash'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goal'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined), label: 'Hisobot'),
          ],
        ),
      );
}
