import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
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
      label: 'Taqsimlash',
    ),
    NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Maqsad'),
    NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Tahlil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: navigationShell),
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: navigationShell.goBranch,
      destinations: _destinations,
    ),
  );
}
