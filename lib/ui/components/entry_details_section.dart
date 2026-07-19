import 'package:flutter/material.dart';

import '../../core/l10n/formatters.dart';
import '../../core/theme/velora_tokens.dart';

/// The shared "Batafsil" (details) collapse used by the expense and income
/// entry sheets: a toggle, then an animated reveal of a date button, a note
/// field, and any [extraChildren] the caller appends (planned switch,
/// recurring interval, etc.). Optional fields stay collapsed by default so
/// the frequent path stays fast (Velora design §6.3/§6.4).
class EntryDetailsSection extends StatelessWidget {
  const EntryDetailsSection({
    super.key,
    required this.open,
    required this.onToggle,
    required this.occurredAt,
    required this.onPickDate,
    required this.noteController,
    required this.noteFieldKey,
    this.extraChildren = const [],
  });

  final bool open;
  final VoidCallback onToggle;
  final DateTime occurredAt;
  final VoidCallback onPickDate;
  final TextEditingController noteController;
  final Key noteFieldKey;

  /// Sheet-specific controls appended below the note field (each caller is
  /// responsible for its own leading spacing).
  final List<Widget> extraChildren;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(open ? Icons.expand_less : Icons.expand_more),
          label: const Text('Batafsil'),
        ),
        AnimatedSize(
          duration: VeloraMotion.standard,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          // Building nothing (not just shrinking) when closed keeps the
          // optional fields genuinely out of the tree, so "collapsed by
          // default" is a real absence, not a zero-height presence.
          child: !open
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onPickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(formatDate(occurredAt, 'yyyy-MM-dd')),
                    ),
                    const SizedBox(height: VeloraSpacing.sm),
                    TextField(
                      key: noteFieldKey,
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Izoh'),
                    ),
                    ...extraChildren,
                  ],
                ),
        ),
      ],
    );
  }
}
