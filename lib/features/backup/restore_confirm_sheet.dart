import 'package:flutter/material.dart';
import '../../data/backup/backup_preview.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_sheet.dart';

/// Pre-import confirmation (PRD §19.2): shows the backup date, per-table row
/// counts, and a warning that all current data will be replaced. Resolves
/// true only if the user taps "Tiklash"; cancel or dismiss resolves false.
Future<bool> showRestoreConfirmSheet(
    BuildContext context, BackupPreview preview) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RestoreConfirmSheetBody(preview: preview),
  );
  return result ?? false;
}

class _RestoreConfirmSheetBody extends StatelessWidget {
  const _RestoreConfirmSheetBody({required this.preview});

  final BackupPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = preview.backupDate;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return VeloraSheetScaffold(
      title: 'Zaxiradan tiklash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zaxira sanasi: $date', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (final entry in preview.counts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: theme.textTheme.bodyMedium),
                  Text('${entry.value}', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            "Diqqat: qurilmadagi mavjud barcha ma'lumot ushbu zaxira bilan "
            "almashtiriladi.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
      primaryAction: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Bekor'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: VeloraPrimaryButton(
              label: 'Tiklash',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
