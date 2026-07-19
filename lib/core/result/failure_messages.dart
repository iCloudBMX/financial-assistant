import 'failure.dart';

/// Maps a [Failure] to non-technical, next-step-oriented text (PRD §26).
String userMessageFor(Failure failure) => switch (failure) {
      StorageFailure() =>
        'Ma\'lumotni saqlab bo\'lmadi. Iltimos, qayta urinib ko\'ring.',
      MigrationFailure() =>
        'Ma\'lumotlarni yangilashda muammo yuz berdi. Eski ma\'lumotlaringiz saqlab qolindi.',
      ValidationFailure() =>
        'Kiritilgan ma\'lumot noto\'g\'ri. Iltimos, tekshirib qayta kiriting.',
      PersistenceFailure() =>
        'O\'zgarishlarni saqlab bo\'lmadi. Iltimos, qayta urinib ko\'ring.',
      CurrencyFailure() =>
        'Bu summalar turli valyutada. Asosiy valyutani tanlab, qayta urinib ko\'ring.',
      NotFoundFailure() => 'So\'ralgan ma\'lumot topilmadi.',
      BackupIncompatibleFailure() =>
        'Bu zaxira nusxasi ilovaning ushbu versiyasi bilan mos emas.',
    };

/// Backwards-compatible name for existing presentation call sites.
String userMessage(Failure failure) => userMessageFor(failure);
