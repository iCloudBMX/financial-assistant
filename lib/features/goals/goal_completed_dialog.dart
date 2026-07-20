import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/goals/goal_model.dart';
import '../../providers/app_providers.dart';
import 'goal_controller.dart';
import 'goal_edit_sheet.dart';

/// §12.7 goal-completion celebration. Offered by the contribute sheet right
/// after a contribution brings a goal's `remaining` to zero. Three actions:
/// close the goal, retarget it (opens the edit sheet), or — only when the
/// goal is over-funded and another goal exists — move the excess to another
/// goal.
Future<void> showGoalCompletedDialog(BuildContext context, WidgetRef ref,
    {required int goalId}) {
  return showDialog<void>(
    context: context,
    builder: (dctx) => Consumer(
      builder: (consumerCtx, consumerRef, _) {
        final goalsAsync = consumerRef.watch(goalsProvider);
        final all = goalsAsync.value;

        final selfMatches = all?.where((g) => g.goal.id == goalId);
        final item =
            (selfMatches == null || selfMatches.isEmpty) ? null : selfMatches.first;

        // Exclude closed goals: activeReserveMinor doesn't count them, so
        // surplus moved into one would silently drop out of the reserve.
        // (archived goals are already excluded by goalsProvider/list().)
        final otherMatches = all?.where((g) =>
            g.goal.id != goalId &&
            (g.goal.status == GoalStatus.active ||
                g.goal.status == GoalStatus.completed));
        final others = (otherMatches == null || otherMatches.isEmpty)
            ? const <GoalWithProgress>[]
            : otherMatches.toList();

        final excessMinor = item == null
            ? 0
            : item.progress.saved.minorUnits - item.progress.target.minorUnits;
        final canMoveSurplus = excessMinor > 0 && others.isNotEmpty;

        return AlertDialog(
          backgroundColor: VeloraColors.blush,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VeloraRadii.sheet),
          ),
          icon: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VeloraColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(VeloraRadii.control),
            ),
            child: const Icon(Icons.celebration_outlined,
                color: VeloraColors.success, size: 30),
          ),
          title: const Text('Tabriklaymiz!'),
          content: Text(
            item == null
                ? 'Maqsadga yetdingiz. Keyingi qadam?'
                : '"${item.goal.name}" maqsadiga yetdingiz. Keyingi qadam?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await consumerRef
                    .read(goalControllerProvider)
                    .closeGoal(goalId);
                if (dctx.mounted) Navigator.of(dctx).pop();
              },
              child: const Text('Yopish'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dctx).pop();
                final g = item?.goal;
                if (g != null) showGoalEditSheet(context, ref, existing: g);
              },
              child: const Text('Yangi target'),
            ),
            if (canMoveSurplus)
              TextButton(
                onPressed: () async {
                  final currency = item!.progress.saved.currency;
                  final picked = await showDialog<int>(
                    context: dctx,
                    builder: (pctx) => SimpleDialog(
                      title: const Text('Qaysi maqsadga?'),
                      children: others
                          .map((o) => SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.of(pctx).pop(o.goal.id),
                                child: Text(o.goal.name),
                              ))
                          .toList(),
                    ),
                  );
                  if (picked != null) {
                    await consumerRef.read(goalControllerProvider).moveSurplus(
                          fromGoalId: goalId,
                          toGoalId: picked,
                          amount: Money(excessMinor, currency),
                        );
                  }
                  if (dctx.mounted) Navigator.of(dctx).pop();
                },
                child: const Text("Ortiqchani ko'chirish"),
              ),
          ],
        );
      },
    ),
  );
}
