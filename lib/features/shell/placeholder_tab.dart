import 'package:flutter/material.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  const PlaceholderTab({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Center(
        key: Key('placeholder_$title'),
        child: Text('$title\n(keyingi bosqichda)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      );
}
