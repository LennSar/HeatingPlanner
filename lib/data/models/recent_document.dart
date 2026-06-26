import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_document.freezed.dart';
part 'recent_document.g.dart';

/// A pointer to an `.hsp` document the user has recently opened or saved.
///
/// In the document-based storage model (see `DECISIONS.md`), the project list
/// is built from these entries rather than from rows in the database. Each
/// entry caches just enough metadata (name + modified time) to render the
/// project card without decompressing the `.hsp` file.
@freezed
abstract class RecentDocument with _$RecentDocument {
  /// Creates a [RecentDocument].
  const factory RecentDocument({
    /// Absolute file-system path of the `.hsp` file.
    required String path,

    /// Cached project name, shown on the project card.
    required String name,

    /// Cached timestamp of the last save, shown on the project card.
    required DateTime modifiedAt,
  }) = _RecentDocument;

  /// Deserialises a [RecentDocument] from its JSON form.
  factory RecentDocument.fromJson(Map<String, dynamic> json) =>
      _$RecentDocumentFromJson(json);
}
