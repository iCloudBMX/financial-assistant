import 'allocation_models.dart';

/// uz-Latn display labels for the system bucket keys. Unknown keys (e.g.
/// future `goal:{id}` / `mortgage`) fall back to the raw key.
String bucketLabel(String bucketKey) => switch (bucketKey) {
      'mandatoryExpenses' => 'Majburiy xarajatlar',
      'variableBudget' => 'O‘zgaruvchan budjet',
      'minReserve' => 'Minimal zaxira',
      _ => bucketKey,
    };

/// uz-Latn label for a direction's RULE TYPE (§8.3): fixed amount,
/// percentage, goal-based, or remaining-balance. Distinct from the
/// direction's destination ([bucketLabel]) and from its specific value
/// (amount/percent), which the caller formats separately.
String allocationMethodLabel(AllocationMethod method) => switch (method) {
      AllocationMethod.fixedAmount => 'Belgilangan summa',
      AllocationMethod.percentage => 'Foiz',
      AllocationMethod.remaining => 'Qolgan summa',
      AllocationMethod.goalBased => 'Maqsad asosida',
    };
