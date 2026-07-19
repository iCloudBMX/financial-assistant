import 'package:flutter/material.dart';

class VeloraPrimaryButton extends StatelessWidget {
  const VeloraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final button = SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  value: reduceMotion ? 0.75 : null,
                  strokeWidth: 2,
                ),
              )
            : Text(label),
      ),
    );

    if (!loading) return button;

    return Semantics(
      label: label,
      value: 'Yuklanmoqda',
      button: true,
      enabled: false,
      child: ExcludeSemantics(child: button),
    );
  }
}
