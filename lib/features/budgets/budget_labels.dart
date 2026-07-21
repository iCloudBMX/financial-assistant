import 'package:flutter/material.dart';

import '../../core/budget/category_budget_engine.dart';
import '../../core/theme/velora_tokens.dart';

String budgetStatusLabel(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => 'rejasiz',
      CategoryLimitStatus.safe => 'xavfsiz',
      CategoryLimitStatus.near => 'rejaga yaqin',
      CategoryLimitStatus.over => 'rejadan oshgan',
    };

/// Maps a category budget status onto the shared Velora status visuals
/// (§10.4 — safe/near/over each carry text + icon + color; red only for
/// `over`). `noLimit` is not itself a safe/near/over state, so it has no
/// [VeloraStatus] — callers render it with a neutral tone instead.
VeloraStatus? budgetVeloraStatus(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => null,
      CategoryLimitStatus.safe => VeloraStatus.safe,
      CategoryLimitStatus.near => VeloraStatus.near,
      CategoryLimitStatus.over => VeloraStatus.over,
    };

IconData budgetStatusIcon(CategoryLimitStatus s) =>
    budgetVeloraStatus(s)?.icon ?? Icons.remove_circle_outline;

Color budgetStatusColor(CategoryLimitStatus s, ColorScheme cs) =>
    budgetVeloraStatus(s)?.color ?? cs.outline;
