import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import 'app_lock_controller.dart';
import 'pin_keypad.dart';

/// Two-stage PIN setup (enter -> confirm) used by both the Settings App Lock
/// toggle and the onboarding security step. Resolves `true` once a confirmed
/// PIN has been written via [AppLockController.setPin], `false` if the user
/// dismisses the sheet. Nothing is stored unless the two entries match.
Future<bool> showPinSetup(
  BuildContext context,
  AppLockController controller,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PinSetupSheet(controller: controller),
  );
  return result ?? false;
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet({required this.controller});
  final AppLockController controller;

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  final List<int> _digits = [];
  String? _first; // null while in the "enter" stage
  String? _error;
  bool _busy = false;

  bool get _confirming => _first != null;

  void _onDigit(int d) {
    if (_busy || _digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == 4) _advance();
  }

  void _onBackspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _advance() async {
    final entered = _digits.join();
    if (!_confirming) {
      // First stage done: remember it and ask for confirmation.
      setState(() {
        _first = entered;
        _digits.clear();
      });
      return;
    }
    if (entered != _first) {
      // Mismatch: restart from the enter stage.
      setState(() {
        _first = null;
        _digits.clear();
        _error = 'PIN kod mos kelmadi';
      });
      return;
    }
    setState(() => _busy = true);
    await widget.controller.setPin(entered);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      key: const Key('pin_setup_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(VeloraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirming ? 'PIN kodni tasdiqlang' : 'PIN kod o\'rnating',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: VeloraSpacing.xs),
            Text(
              _confirming
                  ? 'Xuddi shu 4 raqamni qayta kiriting'
                  : '4 raqamli PIN kod tanlang',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.muted),
            ),
            const SizedBox(height: VeloraSpacing.xl),
            PinDots(filled: _digits.length, error: _error != null),
            const SizedBox(height: VeloraSpacing.md),
            SizedBox(
              height: 20,
              child: _error == null
                  ? null
                  : Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: VeloraSpacing.lg),
            // Reuses the shared PinKeypad (Task 2) with a distinct key prefix
            // so tests can target the setup keypad independently of the lock
            // screen's `app_lock_key_*`. `showBiometric` defaults to false, so
            // the bottom-left corner renders as a blank spacer -- there is no
            // biometric option during PIN setup.
            PinKeypad(
              enabled: !_busy,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              keyPrefix: 'pin_setup_key',
            ),
          ],
        ),
      ),
    );
  }
}
