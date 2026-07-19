import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
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
        error: (e, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(goalsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return VeloraEmptyState(
              icon: Icons.flag_outlined,
              title: "Hali maqsad yo'q",
              message: "Birinchi moliyaviy maqsadingizni qo'shing.",
              action: VeloraPrimaryButton(
                label: 'Maqsad qo\'shish',
                onPressed: () => showGoalEditSheet(context, ref),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(VeloraSpacing.md),
            itemCount: list.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
              child: GoalCard(
                item: list[i],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GoalDetailScreen(goalId: list[i].goal.id),
                )),
              ),
            ),
          );
        },
      ),
    );
  }
}
