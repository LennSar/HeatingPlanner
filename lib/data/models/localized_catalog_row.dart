import 'package:flutter/foundation.dart';

/// A typed catalog row paired with its locale-resolved display strings.
///
/// Catalog providers wrap each underlying [row] in this record so the UI
/// can render its [displayName] / [displayDescription] without knowing
/// which language column the value came from.
///
/// [alternateName] is the same row's name in the *other* supported
/// locale. Search and filter logic match against both [displayName] and
/// [alternateName] so a user typing English in a German UI (or vice
/// versa) still finds the row. It is null when no translation has been
/// seeded — in that case the canonical name is identical in both
/// locales and matching against [displayName] alone is sufficient.
@immutable
class LocalizedCatalogRow<T> {
  /// Creates a [LocalizedCatalogRow].
  const LocalizedCatalogRow({
    required this.row,
    required this.displayName,
    this.displayDescription,
    this.alternateName,
  });

  /// The underlying typed row (freezed model or Drift row).
  final T row;

  /// Locale-appropriate name for display.
  final String displayName;

  /// Locale-appropriate description for display, when one exists.
  final String? displayDescription;

  /// The same row's name in the other supported locale, used by
  /// search/filter logic to match queries typed in either language.
  /// Null when no translation has been seeded.
  final String? alternateName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalizedCatalogRow<T> &&
          other.row == row &&
          other.displayName == displayName &&
          other.displayDescription == displayDescription &&
          other.alternateName == alternateName);

  @override
  int get hashCode => Object.hash(
        row,
        displayName,
        displayDescription,
        alternateName,
      );
}

/// Returns true when [row]'s [LocalizedCatalogRow.displayName] or
/// [LocalizedCatalogRow.alternateName] contains the lower-cased
/// [lowerQuery].
///
/// Caller must lower-case the query once per build to avoid quadratic
/// work when filtering large catalogs.
bool catalogRowMatchesQuery(
  LocalizedCatalogRow<Object?> row,
  String lowerQuery,
) {
  if (row.displayName.toLowerCase().contains(lowerQuery)) return true;
  final alt = row.alternateName;
  if (alt != null && alt.toLowerCase().contains(lowerQuery)) return true;
  return false;
}
