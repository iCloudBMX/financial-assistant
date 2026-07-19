import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/allocation/allocation_result_labels.dart';

void main() {
  test('allocationMethodLabel gives a distinct uz-Latn label for each rule '
      'type: fixed / percentage / goal / remaining', () {
    expect(allocationMethodLabel(AllocationMethod.fixedAmount),
        'Belgilangan summa');
    expect(allocationMethodLabel(AllocationMethod.percentage), 'Foiz');
    expect(
        allocationMethodLabel(AllocationMethod.remaining), 'Qolgan summa');
    expect(allocationMethodLabel(AllocationMethod.goalBased),
        'Maqsad asosida');

    // Every rule type produces a genuinely different label.
    final labels = AllocationMethod.values.map(allocationMethodLabel).toSet();
    expect(labels.length, AllocationMethod.values.length);
  });

  test('bucketLabel is unaffected by the new import', () {
    expect(bucketLabel('minReserve'), 'Minimal zaxira');
  });
}
