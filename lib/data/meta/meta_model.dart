class AppMeta {
  final int schemaVersion;
  final DateTime installedAt;
  final bool onboardingComplete;
  final DateTime? lastBackupAt;
  const AppMeta({
    required this.schemaVersion,
    required this.installedAt,
    required this.onboardingComplete,
    required this.lastBackupAt,
  });
}
