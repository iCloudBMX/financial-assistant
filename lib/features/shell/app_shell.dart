import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../expense_entry/expense_entry_sheet.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

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
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(child: navigationShell),
    // Keep the global action away from feature-local trailing FABs (Goals
    // currently has one) so both actions remain reachable.
    floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('global-expense-action'),
      heroTag: 'global-expense-action',
      onPressed: () => showExpenseEntrySheet(context, ref),
      icon: const Icon(Icons.remove),
      label: const Text('Chiqim'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: navigationShell.goBranch,
      destinations: _destinations,
    ),
  );
}
