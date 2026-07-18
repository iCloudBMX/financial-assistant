import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/settings/settings_model.dart';
import 'settings_controller.dart';

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
              ListTile(
                title: const Text('Ism'),
                subtitle: Text(s.name),
                trailing: const Icon(Icons.edit),
                onTap: () => _editName(context, s.name, save, s),
              ),
              ListTile(
                title: const Text('Valyuta'),
                trailing: DropdownButton<String>(
                  value: s.primaryCurrency.code,
                  items: [
                    for (final c in _currencies)
                      DropdownMenuItem(value: c.code, child: Text(c.code)),
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
                trailing: DropdownButton<String>(
                  value: s.dateFormat,
                  items: [
                    for (final f in _dateFormats)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: (f) {
                    if (f == null) return;
                    save(s.copyWith(dateFormat: f));
                  },
                ),
              ),
              ListTile(
                title: const Text('Davr boshlanish kuni'),
                trailing: DropdownButton<int>(
                  value: s.periodStartDay,
                  items: [
                    for (var day = 1; day <= 31; day++)
                      DropdownMenuItem(value: day, child: Text('$day')),
                  ],
                  onChanged: (day) {
                    if (day == null) return;
                    save(s.copyWith(periodStartDay: day));
                  },
                ),
              ),
              ListTile(
                title: const Text('Hafta boshlanish kuni'),
                trailing: DropdownButton<int>(
                  value: s.weekStartIso,
                  items: [
                    for (var i = 0; i < _weekdayNames.length; i++)
                      DropdownMenuItem(
                          value: i + 1, child: Text(_weekdayNames[i])),
                  ],
                  onChanged: (iso) {
                    if (iso == null) return;
                    save(s.copyWith(weekStartIso: iso));
                  },
                ),
              ),
              ListTile(
                title: const Text('Kunlik limit usuli'),
                trailing: DropdownButton<DailyLimitMethod>(
                  value: s.dailyLimitMethod,
                  items: [
                    for (final m in DailyLimitMethod.values)
                      DropdownMenuItem(
                          value: m, child: Text(_dailyLimitLabel(m))),
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
              ListTile(
                title: const Text('Mavzu'),
                trailing: DropdownButton<ThemeModeSetting>(
                  value: s.themeMode,
                  items: [
                    for (final mode in ThemeModeSetting.values)
                      DropdownMenuItem(
                          value: mode, child: Text(_themeLabel(mode))),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    save(s.copyWith(themeMode: mode));
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Ilova qulfi'),
                value: s.appLockEnabled,
                onChanged: (v) => save(s.copyWith(appLockEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('Biometrik autentifikatsiya'),
                value: s.biometricEnabled,
                onChanged: (v) => save(s.copyWith(biometricEnabled: v)),
              ),
              const Divider(),
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
