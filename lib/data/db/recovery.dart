import 'dart:io';

String recoveryPathFor(String dbPath) => '$dbPath.recovery';

Future<String?> snapshotDatabase(String dbPath) async {
  final src = File(dbPath);
  if (!await src.exists()) return null; // fresh install, nothing to snapshot
  final dst = recoveryPathFor(dbPath);
  await src.copy(dst);
  return dst;
}

Future<void> restoreSnapshot(String snapshotPath, String dbPath) async {
  final snap = File(snapshotPath);
  if (await snap.exists()) {
    await snap.copy(dbPath);
  }
}

Future<void> discardSnapshot(String dbPath) async {
  final snap = File(recoveryPathFor(dbPath));
  if (await snap.exists()) await snap.delete();
}
