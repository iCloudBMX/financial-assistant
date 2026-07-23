/// Read-only summary of a validated backup, shown on the pre-import sheet
/// (PRD §19.2). `validatedTempPath` points at an already-migrated copy of the
/// backup, ready to be swapped in by [BackupService.commit].
class BackupPreview {
  final int schemaVersion;
  final DateTime backupDate;
  final Map<String, int> counts; // Uzbek label -> row count
  final String validatedTempPath;
  const BackupPreview({
    required this.schemaVersion,
    required this.backupDate,
    required this.counts,
    required this.validatedTempPath,
  });
}
