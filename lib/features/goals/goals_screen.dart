import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'goal_card.dart';
import 'goal_detail_screen.dart';
import 'goal_edit_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Maqsadlar")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showGoalEditSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Hali maqsad yo'q. Birinchi moliyaviy maqsadingizni qo'shing.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => GoalCard(
              item: list[i],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GoalDetailScreen(goalId: list[i].goal.id),
              )),
            ),
          );
        },
      ),
    );
  }
}
