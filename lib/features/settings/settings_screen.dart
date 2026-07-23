import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/result/result.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/backup/backup_preview.dart';
import '../../data/settings/settings_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/app_snackbar.dart';
import '../backup/restore_complete_screen.dart';
import '../backup/restore_confirm_sheet.dart';
import '../categories/category_management_screen.dart';
import '../security/pin_setup_sheet.dart';
import 'settings_controller.dart';

/// A group header for the grouped Settings layout (design spec sec. 6.12):
/// profile, financial preferences, notifications, appearance, privacy &
/// security, and data management -- each with its own heading so the
/// screen reads as sections rather than one long flat list. Styled as a
/// quiet muted label (the mockup's uppercase section eyebrow) so the grouped
/// cards below carry the visual weight.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.xs,
          VeloraSpacing.md,
          VeloraSpacing.xs,
          VeloraSpacing.sm,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: VeloraColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
      );
}

/// Wraps a section's rows in one rounded 22px card with a 1px `line` border
/// and hairline dividers between rows -- the mockup's grouped "menu" surface
/// (design spec sec. 6.12) instead of edge-to-edge flat list tiles.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Material (not a decorated Container) so each ListTile paints its ink
    // splashes and disabled/hover states on a real Material ancestor -- a
    // colored Container between ListTile and its Material would swallow them
    // (Flutter asserts on exactly this).
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        side: const BorderSide(color: VeloraColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: VeloraColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A soft rounded leading tile that gives each settings row the mockup's
/// plum-tinted icon chip.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VeloraColors.plumTint,
          borderRadius: BorderRadius.circular(VeloraRadii.control),
        ),
        child: Icon(icon, size: 18, color: VeloraColors.plum),
      );
}

/// The plum profile hero at the top of Settings (design spec sec. 6.12): an
/// apricot initials avatar, the user's name, and a "local-only" reassurance,
/// echoing the mockup's profile card.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '•'
        : trimmed
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w.substring(0, 1).toUpperCase())
            .join();
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VeloraColors.apricot,
              borderRadius: BorderRadius.circular(VeloraRadii.control),
            ),
            child: Text(
              initials,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.titleMedium?.copyWith(
                color: VeloraColors.inkberry,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trimmed.isEmpty ? 'Velora' : trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  "Mahalliy profil · ma'lumot faqat qurilmangizda",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A dropdown trailing constrained to a fixed max width with ellipsis text,
/// used for every settings row that picks from a short list of values. A
/// bare `DropdownButton` sizes itself to its widest item's intrinsic width
/// and never shrinks below it, so at narrow widths (320px, or a long label
/// like "Belgilangan kunlik summa") it would overflow the `ListTile` row
/// instead of reflowing (spec sec. 8: dense rows reflow, never clip via a
/// layout exception).
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      );
}

DropdownMenuItem<T> _dropdownItem<T>(T value, String label) =>
    DropdownMenuItem(
      value: value,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );

Future<bool> _confirmDisableLock(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ilova qulfini o\'chirasizmi?'),
      content: const Text(
          'PIN kod o\'chiriladi va ilova qulfsiz ochiladi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('O\'chirish'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _currencies = [
    CurrencyRegistry.uzs,
    CurrencyRegistry.usd,
    CurrencyRegistry.eur,
  ];

  static const _dateFormats = [
    'dd.MM.yyyy',
    'yyyy-MM-dd',
    'MM/dd/yyyy',
  ];

  static const _weekdayNames = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];

  static String _themeLabel(ThemeModeSetting mode) => switch (mode) {
        ThemeModeSetting.system => 'Tizim',
        ThemeModeSetting.light => 'Yorug\'',
        ThemeModeSetting.dark => 'Qorong\'i',
      };

  static String _dailyLimitLabel(DailyLimitMethod method) => switch (method) {
        DailyLimitMethod.evenSplit => 'Tekis taqsimlash',
        DailyLimitMethod.fixedDaily => 'Belgilangan kunlik summa',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sozlamalar'),
        backgroundColor: VeloraColors.blush,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (s) {
          void save(AppSettings updated) =>
              ref.read(settingsControllerProvider.notifier).save(updated);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              VeloraSpacing.lg,
              VeloraSpacing.sm,
              VeloraSpacing.lg,
              VeloraSpacing.xl,
            ),
            children: [
              _ProfileHero(name: s.name),
              const _SectionHeader('Profil'),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const _RowIcon(Icons.person_outline),
                    title: const Text('Ism'),
                    subtitle: Text(s.name),
                    trailing: const Icon(Icons.edit, color: VeloraColors.muted),
                    onTap: () => _editName(context, s.name, save, s),
                  ),
                ],
              ),
              const _SectionHeader('Moliyaviy sozlamalar'),
              _SettingsGroup(
                children: [
                  ListTile(
                    key: const Key('settings-categories'),
                    leading: const _RowIcon(Icons.category_outlined),
                    title: const Text('Kategoriyalar'),
                    trailing: const Icon(Icons.chevron_right,
                        color: VeloraColors.muted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CategoryManagementScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.payments_outlined),
                    title: const Text('Valyuta'),
                    trailing: _DropdownField<String>(
                      value: s.primaryCurrency.code,
                      items: [
                        for (final c in _currencies)
                          _dropdownItem(c.code, c.code),
                      ],
                      onChanged: (code) {
                        if (code == null) return;
                        final currency = CurrencyRegistry.byCode(code);
                        save(s.copyWith(
                          primaryCurrency: currency,
                          minReserve: Money.zero(currency),
                        ));
                      },
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.event_note_outlined),
                    title: const Text('Sana formati'),
                    trailing: _DropdownField<String>(
                      value: s.dateFormat,
                      items: [
                        for (final f in _dateFormats) _dropdownItem(f, f),
                      ],
                      onChanged: (f) {
                        if (f == null) return;
                        save(s.copyWith(dateFormat: f));
                      },
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.calendar_today_outlined),
                    title: const Text('Davr boshlanish kuni'),
                    trailing: _DropdownField<int>(
                      value: s.periodStartDay,
                      items: [
                        for (var day = 1; day <= 31; day++)
                          _dropdownItem(day, '$day'),
                      ],
                      onChanged: (day) {
                        if (day == null) return;
                        save(s.copyWith(periodStartDay: day));
                      },
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.date_range_outlined),
                    title: const Text('Hafta boshlanish kuni'),
                    trailing: _DropdownField<int>(
                      value: s.weekStartIso,
                      items: [
                        for (var i = 0; i < _weekdayNames.length; i++)
                          _dropdownItem(i + 1, _weekdayNames[i]),
                      ],
                      onChanged: (iso) {
                        if (iso == null) return;
                        save(s.copyWith(weekStartIso: iso));
                      },
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.tune_outlined),
                    title: const Text('Kunlik limit usuli'),
                    trailing: _DropdownField<DailyLimitMethod>(
                      value: s.dailyLimitMethod,
                      items: [
                        for (final m in DailyLimitMethod.values)
                          _dropdownItem(m, _dailyLimitLabel(m)),
                      ],
                      onChanged: (m) {
                        if (m == null) return;
                        save(s.copyWith(dailyLimitMethod: m));
                      },
                    ),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.savings_outlined),
                    title: const Text('Minimal zaxira'),
                    subtitle: Text(s.minReserve.format()),
                    trailing:
                        const Icon(Icons.edit, color: VeloraColors.muted),
                    onTap: () => _editReserve(context, s, save),
                  ),
                ],
              ),
              const _SectionHeader('Bildirishnomalar'),
              const _SettingsGroup(
                children: [
                  ListTile(
                    enabled: false,
                    leading: _RowIcon(Icons.notifications_outlined),
                    title: Text('Bildirishnoma turlari'),
                    subtitle: Text('(keyingi bosqichda)'),
                  ),
                ],
              ),
              const _SectionHeader("Ko'rinish"),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const _RowIcon(Icons.palette_outlined),
                    title: const Text('Mavzu'),
                    trailing: _DropdownField<ThemeModeSetting>(
                      value: s.themeMode,
                      items: [
                        for (final mode in ThemeModeSetting.values)
                          _dropdownItem(mode, _themeLabel(mode)),
                      ],
                      onChanged: (mode) {
                        if (mode == null) return;
                        save(s.copyWith(themeMode: mode));
                      },
                    ),
                  ),
                ],
              ),
              const _SectionHeader('Maxfiylik va xavfsizlik'),
              _SettingsGroup(
                children: [
                  SwitchListTile(
                    secondary: const _RowIcon(Icons.lock_outline),
                    title: const Text('Ilova qulfi'),
                    subtitle: const Text('PIN kod bilan ilovani himoyalash'),
                    value: s.appLockEnabled,
                    onChanged: (want) async {
                      final lock = ref.read(appLockControllerProvider);
                      if (want) {
                        final ok = await showPinSetup(context, lock);
                        if (ok) save(s.copyWith(appLockEnabled: true));
                      } else {
                        final confirmed = await _confirmDisableLock(context);
                        if (confirmed) {
                          await lock.clearPin();
                          save(s.copyWith(
                            appLockEnabled: false,
                            biometricEnabled: false,
                          ));
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    secondary: const _RowIcon(Icons.fingerprint),
                    title: const Text('Biometrik autentifikatsiya'),
                    value: s.biometricEnabled,
                    onChanged: s.appLockEnabled
                        ? (want) => save(s.copyWith(biometricEnabled: want))
                        : null,
                  ),
                ],
              ),
              const _SectionHeader("Ma'lumotlar"),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const _RowIcon(Icons.download_outlined),
                    title: const Text('Zaxira nusxa yaratish'),
                    onTap: () => _exportBackup(context, ref),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.restore_outlined),
                    title: const Text('Zaxiradan tiklash'),
                    onTap: () => _restoreBackup(context, ref),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    String currentName,
    void Function(AppSettings) save,
    AppSettings s,
  ) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ism'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      save(s.copyWith(name: result.trim()));
    }
  }

  Future<void> _editReserve(
    BuildContext context,
    AppSettings s,
    void Function(AppSettings) save,
  ) async {
    // Symbol-less numeric form so an unchanged field re-parses to the same
    // reserve; format() would embed the currency symbol, which tryParse
    // rejects → "Saqlash" unedited would silently drop the edit, leaving
    // minReserve unchanged with no error shown (it feeds allocation's
    // minimum-reserve bucket; the model-A daily limit no longer reads it).
    final controller =
        TextEditingController(text: s.minReserve.formatNumber());
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minimal zaxira'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final parsed = Money.tryParse(result, s.primaryCurrency);
    if (parsed != null) {
      save(s.copyWith(minReserve: parsed));
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final r = await ref.read(backupControllerProvider).exportAndShare();
    if (!context.mounted) return;
    r.when(
      ok: (_) {},
      err: (f) => ScaffoldMessenger.of(context)
          .showAutoDismissSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(backupControllerProvider).pickAndValidate();
    if (!context.mounted) return;
    if (picked is Err<BackupPreview?>) {
      ScaffoldMessenger.of(context).showAutoDismissSnackBar(
          SnackBar(content: Text(userMessageFor(picked.failure))));
      return;
    }
    final preview = picked.valueOrNull;
    if (preview == null) return; // cancelled
    final confirmed = await showRestoreConfirmSheet(context, preview);
    if (!confirmed || !context.mounted) return;
    final done = await ref.read(backupControllerProvider).confirm(preview);
    if (!context.mounted) return;
    done.when(
      ok: (_) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestoreCompleteScreen()),
        (route) => false,
      ),
      err: (f) => ScaffoldMessenger.of(context)
          .showAutoDismissSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }
}
