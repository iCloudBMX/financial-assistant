import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/backup/backup_preview.dart';
import 'package:financial_assistant/features/backup/restore_confirm_sheet.dart';

void main() {
  testWidgets('shows counts and returns true on confirm', (tester) async {
    final preview = BackupPreview(
      schemaVersion: 8,
      backupDate: DateTime(2026, 7, 20),
      counts: const {'Hisoblar': 4, 'Tranzaksiyalar': 312},
      validatedTempPath: '/tmp/validate.db',
    );
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                result = await showRestoreConfirmSheet(context, preview),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('312'), findsWidgets); // a count is shown
    await tester.tap(find.text('Tiklash'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancel returns false', (tester) async {
    final preview = BackupPreview(
      schemaVersion: 8,
      backupDate: DateTime(2026, 7, 20),
      counts: const {'Hisoblar': 4},
      validatedTempPath: '/tmp/validate.db',
    );
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                result = await showRestoreConfirmSheet(context, preview),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bekor'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
