import 'package:drift/drift.dart';
import 'app_database.dart';

/// The default allocation template (§8.3). A neutral starter: reserve 10% of
/// each income, everything else becomes the variable spending budget. Users
/// add fixed mandatory-expense / goal / mortgage directions themselves.
/// Tuple: (bucketKey, method, valueMinor, percentBp).
const List<(String, String, int?, int?)> kDefaultAllocationTemplate = [
  ('minReserve', 'percentage', null, 1000), // 10%
  ('variableBudget', 'remaining', null, null),
];

Future<void> seedDefaultAllocationTemplate(AppDatabase db) async {
  final existing = await db.select(db.allocationDirectionsTable).get();
  if (existing.isNotEmpty) return;
  for (var i = 0; i < kDefaultAllocationTemplate.length; i++) {
    final (bucketKey, method, valueMinor, percentBp) =
        kDefaultAllocationTemplate[i];
    await db.into(db.allocationDirectionsTable).insert(
          AllocationDirectionsTableCompanion.insert(
            bucketKey: bucketKey,
            method: method,
            valueMinor: Value(valueMinor),
            percentBp: Value(percentBp),
            sortOrder: Value(i),
          ),
        );
  }
}
