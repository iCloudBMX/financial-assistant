import 'dart:ui';

import 'package:flutter/material.dart';

/// Blurs the app content while it is inactive/paused so sensitive amounts
/// do not show up in the OS app switcher (spec sec. 22.3).
class BackgroundShield extends StatefulWidget {
  final Widget child;
  const BackgroundShield({super.key, required this.child});
  @override
  State<BackgroundShield> createState() => _BackgroundShieldState();
}

class _BackgroundShieldState extends State<BackgroundShield>
    with WidgetsBindingObserver {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _obscure = state != AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          if (_obscure)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),
            ),
        ],
      );
}
