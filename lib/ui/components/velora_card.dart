import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';

class VeloraCard extends StatelessWidget {
  const VeloraCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(VeloraSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(VeloraRadii.card);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
