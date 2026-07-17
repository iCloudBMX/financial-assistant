import 'failure.dart';

/// Maps a [Failure] to non-technical, next-step-oriented text (PRD §26).
String userMessage(Failure failure) => switch (failure) {
      StorageFailure() =>
        'Ma\'lumotni saqlab bo\'lmadi. Iltimos, qayta urinib ko\'ring.',
      MigrationFailure() =>
        'Ma\'lumotlarni yangilashda muammo yuz berdi. Eski ma\'lumotlaringiz saqlab qolindi.',
      ValidationFailure() =>
        'Kiritilgan ma\'lumot noto\'g\'ri. Iltimos, tekshirib qayta kiriting.',
      NotFoundFailure() => 'So\'ralgan ma\'lumot topilmadi.',
      BackupIncompatibleFailure() =>
        'Bu zaxira nusxasi ilovaning ushbu versiyasi bilan mos emas.',
    };
