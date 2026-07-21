import '../ledger/ledger_entry.dart';

/// A transaction's type label as it appears in history (Velora design §6.6):
/// transfer legs are never shown as income or expense, and balance
/// adjustments are always visibly labeled.
String transactionTypeLabel(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => 'Chiqim',
      LedgerEntryType.income => 'Kirim',
      LedgerEntryType.transferOut => 'O\'tkazma (chiqdi)',
      LedgerEntryType.transferIn => 'O\'tkazma (kirdi)',
      LedgerEntryType.adjustment => 'Balans tuzatish',
    };

/// Uzbek labels for income sub-types, shown as a row's category line.
String incomeTypeLabel(IncomeType t) => switch (t) {
      IncomeType.salary => 'Maosh',
      IncomeType.bonus => 'Bonus',
      IncomeType.freelance => 'Frilans',
      IncomeType.refund => 'Qaytarim',
      IncomeType.other => 'Boshqa',
    };

/// The two text lines of a history row: a primary [title] and an optional
/// [subtitle]. A null subtitle renders as a single-line row.
class RowContent {
  final String title;
  final String? subtitle;
  const RowContent(this.title, this.subtitle);
}

/// Resolves a row's title/subtitle. The user's note ("what it was spent on")
/// leads when present; otherwise the category / income-type / operation label
/// is promoted to the title and the account name drops to the subtitle, so the
/// two lines never repeat the same text.
RowContent resolveRowContent(
  LedgerEntry e, {
  String? accountName,
  String? categoryName,
}) {
  String? clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;
  final note = clean(e.note);
  final acc = clean(accountName);

  switch (e.type) {
    case LedgerEntryType.expense:
      final cat = clean(categoryName) ?? 'Chiqim';
      return note != null ? RowContent(note, cat) : RowContent(cat, acc);
    case LedgerEntryType.income:
      final label =
          e.incomeType != null ? incomeTypeLabel(e.incomeType!) : 'Kirim';
      return note != null ? RowContent(note, label) : RowContent(label, acc);
    case LedgerEntryType.transferOut:
    case LedgerEntryType.transferIn:
    case LedgerEntryType.adjustment:
      final op = transactionTypeLabel(e.type);
      return note != null ? RowContent(note, op) : RowContent(op, acc);
  }
}
