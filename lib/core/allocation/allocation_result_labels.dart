/// uz-Latn display labels for the system bucket keys. Unknown keys (e.g.
/// future `goal:{id}` / `mortgage`) fall back to the raw key.
String bucketLabel(String bucketKey) => switch (bucketKey) {
      'mandatoryExpenses' => 'Majburiy xarajatlar',
      'variableBudget' => 'O‘zgaruvchan budjet',
      'minReserve' => 'Minimal zaxira',
      _ => bucketKey,
    };
