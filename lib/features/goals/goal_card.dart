import 'package:flutter/material.dart';
import '../../providers/app_providers.dart';

class GoalCard extends StatelessWidget {
  final GoalWithProgress item;
  final VoidCallback? onTap;
  const GoalCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = item.progress;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.flag_outlined),
        title: Text(item.goal.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(
                value: (p.percentBp / 10000).clamp(0.0, 1.0)),
            const SizedBox(height: 6),
            Text('${p.saved.format()} / ${p.target.format()}'),
            Text(
                '${(p.percentBp / 100).toStringAsFixed(0)}% · qoldi ${p.remaining.format()}'),
            if (p.requiredMonthly != null)
              Text('oyiga kerak: ${p.requiredMonthly!.format()}'),
            if (p.projectedDate != null)
              Text('taxminiy sana: ${p.projectedDate!.toIso8601String().split('T').first}'),
          ],
        ),
      ),
    );
  }
}
