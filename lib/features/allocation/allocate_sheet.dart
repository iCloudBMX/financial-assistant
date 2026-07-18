import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../core/money/money.dart';
import 'allocation_controller.dart';

/// §8.4 confirm screen: shows total income, each direction's amount (editable),
/// total allocated, undistributed remainder, and free balance after. Returns
/// true when the user confirms.
class AllocateSheet extends ConsumerStatefulWidget {
  final int incomeId;
  final Money income;
  const AllocateSheet(
      {super.key, required this.incomeId, required this.income});

  @override
  ConsumerState<AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<AllocateSheet> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(allocationControllerProvider).preview(widget.income);
    for (final e in result.perBucket.entries) {
      _ctrls[e.key] = TextEditingController(text: e.value.format());
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, Money> _current() {
    final c = widget.income.currency;
    final out = <String, Money>{};
    _ctrls.forEach((k, ctrl) {
      final m = Money.tryParse(ctrl.text, c);
      if (m != null && m.minorUnits > 0) out[k] = m;
    });
    return out;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final current = _current();
    final allocated = current.values.fold<int>(0, (s, m) => s + m.minorUnits);
    final undistributed = widget.income.minorUnits - allocated;
    final c = widget.income.currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kirimni taqsimlash',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Jami kirim: ${widget.income.format()}'),
          const SizedBox(height: 12),
          ..._ctrls.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(bucketLabel(e.key))),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(),
          Text('Taqsimlangan: ${Money(allocated, c).format()}'),
          Text('Taqsimlanmagan: ${Money(undistributed, c).format()}',
              style: TextStyle(
                  color: undistributed < 0
                      ? Theme.of(context).colorScheme.error
                      : null)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: undistributed < 0
                ? null
                : () async {
                    await ref
                        .read(allocationControllerProvider)
                        .confirm(widget.incomeId, current);
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );
  }
}
