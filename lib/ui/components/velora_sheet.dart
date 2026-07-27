import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';

class VeloraSheetScaffold extends StatelessWidget {
  const VeloraSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.primaryAction,
    this.titleTrailing,
  });

  final String title;
  final Widget body;
  final Widget primaryAction;

  /// Optional compact control shown at the trailing edge of the title row
  /// (e.g. the expense sheet's date pill). Null keeps the plain title.
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.disableAnimations;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: AnimatedPadding(
          duration: reduceMotion ? Duration.zero : VeloraMotion.standard,
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(VeloraRadii.sheet),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VeloraSpacing.lg,
                VeloraSpacing.xl,
                VeloraSpacing.lg,
                VeloraSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      ?titleTrailing,
                    ],
                  ),
                  const SizedBox(height: VeloraSpacing.lg),
                  Expanded(child: SingleChildScrollView(child: body)),
                  const SizedBox(height: VeloraSpacing.lg),
                  primaryAction,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
