enum CategoryKind { mandatory, variable }

class Category {
  final int id;
  final String name;
  final String icon;
  final bool isDefault;
  final bool archived;
  final CategoryKind kind;
  final int? monthlyLimitMinor;
  final int? weeklyLimitMinor;
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.isDefault,
    required this.archived,
    this.kind = CategoryKind.variable,
    this.monthlyLimitMinor,
    this.weeklyLimitMinor,
  });
}
