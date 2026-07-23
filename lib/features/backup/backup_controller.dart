import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result/result.dart';
import '../../data/backup/backup_preview.dart';
import '../../data/backup/backup_service.dart';

/// Thin glue between [BackupService] and the platform (temp dir, share sheet,
/// file picker). Not unit-tested — it wraps plugins; the logic lives in the
/// service, which is fully covered.
class BackupController {
  final BackupService service;
  BackupController(this.service);

  /// Exports a backup and opens the OS share sheet (PRD §18.2).
  Future<Result<void>> exportAndShare() async {
    final tmp = await getTemporaryDirectory();
    final dest = p.join(tmp.path, 'financial-assistant-${_stamp(DateTime.now())}.fabackup');
    final r = await service.exportTo(dest);
    if (r is Err<void>) return r;
    // share_plus v12 API: SharePlus.instance.share(ShareParams(...)).
    await SharePlus.instance.share(ShareParams(files: [XFile(dest)]));
    return const Ok(null);
  }

  /// Picks a file and validates it. `Ok(null)` means the user cancelled.
  Future<Result<BackupPreview?>> pickAndValidate() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return const Ok(null);
    final tmp = await getTemporaryDirectory();
    final r = await service.validate(path, p.join(tmp.path, 'restore'));
    return r.when(ok: (preview) => Ok(preview), err: (f) => Err(f));
  }

  Future<Result<void>> confirm(BackupPreview preview) => service.commit(preview);

  String _stamp(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}
