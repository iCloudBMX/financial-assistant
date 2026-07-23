import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';

/// Row of PIN entry dots, shared by the lock screen and the PIN-setup sheet.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.error,
    this.length = 4,
  });

  final int filled;
  final bool error;
  final int length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = error ? colorScheme.error : colorScheme.primary;
    return Semantics(
      label: '$filled / $length raqam kiritildi',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloraSpacing.sm,
                ),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < filled ? color : Colors.transparent,
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 0-9 keypad with a backspace and an optional biometric-retry key.
/// Digit keys carry `Key('${keyPrefix}_$d')` (default prefix `app_lock_key`)
/// so both the lock screen and its existing widget tests keep working after
/// the extraction, while a later reuse (e.g. the PIN-setup sheet) can pass a
/// different [keyPrefix] to avoid colliding with the lock screen's keys. The
/// biometric-retry key is always the literal `Key('app_lock_biometric_retry')`.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    this.showBiometric = false,
    this.onBiometricRetry,
    this.keyPrefix = 'app_lock_key',
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final bool showBiometric;
  final VoidCallback? onBiometricRetry;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    Widget digitButton(int d) => PinKeypadButton(
          key: Key('${keyPrefix}_$d'),
          onPressed: enabled ? () => onDigit(d) : null,
          semanticLabel: '$d raqami',
          child: Text('$d'),
        );

    Widget row(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: children,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digitButton(1), digitButton(2), digitButton(3)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digitButton(4), digitButton(5), digitButton(6)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digitButton(7), digitButton(8), digitButton(9)]),
        const SizedBox(height: VeloraSpacing.md),
        row([
          if (showBiometric)
            PinKeypadButton(
              key: const Key('app_lock_biometric_retry'),
              onPressed: enabled ? onBiometricRetry : null,
              semanticLabel: 'Biometrik orqali qayta urinish',
              child: const Icon(Icons.fingerprint, color: VeloraColors.plum),
            )
          else
            const SizedBox(width: 56, height: 56),
          digitButton(0),
          PinKeypadButton(
            key: Key('${keyPrefix}_backspace'),
            onPressed: enabled ? onBackspace : null,
            semanticLabel: "Bitta raqamni o'chirish",
            child:
                const Icon(Icons.backspace_outlined, color: VeloraColors.plum),
          ),
        ]),
      ],
    );
  }
}

/// A single 56x56 keypad key; digit glyphs opt out of system text scaling so
/// the fixed touch target never overflows at 200% scale.
class PinKeypadButton extends StatelessWidget {
  const PinKeypadButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            onTap: onPressed,
            child: ExcludeSemantics(
              child: Center(
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.headlineSmall,
                    child: IconTheme.merge(
                      data: const IconThemeData(size: 24),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
