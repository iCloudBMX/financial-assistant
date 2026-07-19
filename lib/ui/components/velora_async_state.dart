import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';

class VeloraEmptyState extends StatelessWidget {
  const VeloraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VeloraSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: iconColor ?? theme.colorScheme.primary,
              ),
              const SizedBox(height: VeloraSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: VeloraSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: VeloraSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VeloraErrorState extends StatelessWidget {
  const VeloraErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Qayta urinish',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return VeloraEmptyState(
      icon: Icons.error_outline,
      iconColor: VeloraColors.critical,
      title: message,
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(retryLabel),
      ),
    );
  }
}

class VeloraSkeleton extends StatelessWidget {
  const VeloraSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = VeloraRadii.control,
    this.semanticLabel = 'Yuklanmoqda',
  });

  final double width;
  final double height;
  final double borderRadius;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
