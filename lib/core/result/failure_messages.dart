import 'failure.dart';

/// Maps a [Failure] to non-technical, next-step-oriented text (PRD §26).
String userMessageFor(Failure failure) => switch (failure) {
      StorageFailure() =>
        'Tanlangan faylni o\'qib yoki saqlab bo\'lmadi. Boshqa joylashuvni tanlang va fayl ruxsatlarini tekshiring.',
      MigrationFailure() =>
        'Ma\'lumotlar bazasini yangilashda muammo yuz berdi. Ilovani qayta ishga tushiring; muammo davom etsa, zaxira nusxasini tiklang.',
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
