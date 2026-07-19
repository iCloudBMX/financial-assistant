import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/settings/settings_model.dart';
import 'settings_controller.dart';

/// A group header for the grouped Settings layout (design spec sec. 6.12):
/// profile, financial preferences, notifications, appearance, privacy &
/// security, and data management -- each with its own heading so the
/// screen reads as sections rather than one long flat list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.lg,
          VeloraSpacing.xl,
          VeloraSpacing.lg,
          VeloraSpacing.sm,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
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
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (s) {
          void save(AppSettings updated) =>
              ref.read(settingsControllerProvider.notifier).save(updated);

          return ListView(
            children: [
              const _SectionHeader('Profil'),
              ListTile(
                title: const Text('Ism'),
                subtitle: Text(s.name),
                trailing: const Icon(Icons.edit),
                onTap: () => _editName(context, s.name, save, s),
              ),
              const _SectionHeader('Moliyaviy sozlamalar'),
              ListTile(
                title: const Text('Valyuta'),
                trailing: _DropdownField<String>(
                  value: s.primaryCurrency.code,
                  items: [
                    for (final c in _currencies) _dropdownItem(c.code, c.code),
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
                title: const Text('Minimal zaxira'),
                subtitle: Text(s.minReserve.format()),
                trailing: const Icon(Icons.edit),
                onTap: () => _editReserve(context, s, save),
              ),
              const _SectionHeader('Bildirishnomalar'),
              const ListTile(
                enabled: false,
                title: Text('Bildirishnoma turlari'),
                subtitle: Text('(keyingi bosqichda)'),
              ),
              const _SectionHeader("Ko'rinish"),
              ListTile(
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
              const _SectionHeader('Maxfiylik va xavfsizlik'),
              // Deferred like the export/notification tiles below: there is
              // no PIN-setup flow yet (AppLockController.setPin is never
              // called anywhere in the app), so a live switch here could set
              // appLockEnabled=true with no PIN ever stored. On the next cold
              // start AppLockGate would show a PIN pad that can never be
              // satisfied — verifyPin always returns false with no stored
              // PIN — permanently locking the user out of their data with
              // biometrics off. Keep these disabled until a real PIN-setup
              // flow lands (see settings_screen_test.dart).
              const ListTile(
                enabled: false,
                title: Text('Ilova qulfi'),
                subtitle: Text('(keyingi bosqichda)'),
              ),
              const ListTile(
                enabled: false,
                title: Text('Biometrik autentifikatsiya'),
                subtitle: Text('(keyingi bosqichda)'),
              ),
              const _SectionHeader("Ma'lumotlar"),
              const ListTile(
                enabled: false,
                title: Text("Ma'lumotlarni eksport qilish"),
                subtitle: Text('(keyingi bosqichda)'),
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
    // minReserve unchanged with no error shown (it feeds the safe-limit
    // free balance).
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
}
