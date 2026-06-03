import 'dart:convert';

/// Encodes a [MaterialEntry.categoryPath] list to the JSON-string form
/// stored in `material_entries.category_path` (`DECISIONS.md` ADR-022
/// Rule 2 / architect §5.3).
String encodeCategoryPath(List<String> path) => jsonEncode(path);

/// Decodes a `material_entries.category_path` cell into a list of
/// segments. Tolerates the v17 → v18 migration's `json_array(category,
/// subcategory)` output where the subcategory was the empty string by
/// dropping trailing empty segments — paths must be non-empty per
/// ADR-022 Rule 1.
List<String> decodeCategoryPath(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw FormatException('category_path is not a JSON array: $raw');
  }
  final segments = decoded.map((e) => e as String).toList();
  while (segments.isNotEmpty && segments.last.isEmpty) {
    segments.removeLast();
  }
  return segments;
}
