import 'package:flutter/material.dart';

/// The goal detail screen. Stub for Task 8 — Task 11 replaces this with the
/// real detail view (contributions, edit/close actions, etc).
class GoalDetailScreen extends StatelessWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maqsad')),
      body: Center(child: Text('Goal #$goalId')),
    );
  }
}
