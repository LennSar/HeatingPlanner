import 'package:uuid/uuid.dart';

/// Generates UUID v4 identifiers.
abstract final class IdGenerator {
  static const _uuid = Uuid();

  /// Returns a new UUID v4 string.
  static String newId() => _uuid.v4();
}
