import 'package:flutter/material.dart';

/// Terminal screen after a successful restore. We do not reload the DB in place;
/// the user reopens the app so all providers rebuild against the restored file.
class RestoreCompleteScreen extends StatelessWidget {
  const RestoreCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Tiklash tugadi',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                "Ma'lumotlar tiklandi. O'zgarishlar kuchga kirishi uchun ilovani qayta oching.",
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
