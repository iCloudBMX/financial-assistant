import 'package:flutter/material.dart';

/// The fixed set of icon keys a category can carry (matches
/// `kDefaultCategories`' `icon` values plus the generic fallback). Shared by
/// [CategoryPicker] and `category_edit_sheet.dart` so both surfaces offer and
/// render the exact same icon set.
const List<String> kCategoryIconKeys = [
  'restaurant',
  'directions_car',
  'home',
  'bolt',
  'favorite',
  'school',
  'checkroom',
  'movie',
  'fastfood',
  'subscriptions',
  'card_giftcard',
  'flight',
  'category',
];

/// Maps a stored category icon key to its `Icons` glyph. Unknown keys (future
/// additions, corrupt data) fall back to the generic category icon.
IconData categoryIcon(String icon) => switch (icon) {
      'restaurant' => Icons.restaurant_outlined,
      'directions_car' => Icons.directions_car_outlined,
      'home' => Icons.home_outlined,
      'bolt' => Icons.bolt_outlined,
      'favorite' => Icons.favorite_outline,
      'school' => Icons.school_outlined,
      'checkroom' => Icons.checkroom_outlined,
      'movie' => Icons.movie_outlined,
      'fastfood' => Icons.fastfood_outlined,
      'subscriptions' => Icons.subscriptions_outlined,
      'card_giftcard' => Icons.card_giftcard_outlined,
      'flight' => Icons.flight_outlined,
      _ => Icons.category_outlined,
    };
