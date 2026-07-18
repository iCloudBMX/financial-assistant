import 'package:flutter/material.dart';
import 'placeholder_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    PlaceholderTab(title: 'Bosh sahifa'),
    PlaceholderTab(title: 'Tranzaksiyalar'),
    PlaceholderTab(title: 'Taqsimlash'),
    PlaceholderTab(title: "Goal'lar"),
    PlaceholderTab(title: 'Hisobotlar'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _tabs[_index]),
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
