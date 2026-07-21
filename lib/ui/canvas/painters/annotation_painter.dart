import 'dart:math' show atan2, max, min, pi, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../calculation/engines/geometry_engine.dart';
import '../../../data/models/point2d.dart';
import '../../../data/models/room.dart';
import '../../../data/models/wall_segment.dart';

/// A single laid-out dimension label, positioned in world coordinates.
///
/// The expensive part of a label is the `ui.Paragraph` layout; once built it
/// is invariant to pan/zoom because the world→screen transform is applied by
/// the canvas, not baked into the paragraph. Drawing one is therefore cheap:
/// translate to the world pivot, rotate, centre, and blit the paragraph.
class _LabelEntry {
  _LabelEntry({
    required this.paragraph,
    required this.pivotX,
    required this.pivotY,
    required this.angle,
  });

  /// Pre-laid-out paragraph (text + style baked in).
  final ui.Paragraph paragraph;

  /// World-space anchor the label is centred on.
  final double pivotX;
  final double pivotY;

  /// Rotation in radians (0 for axis-centred room labels).
  final double angle;

  void draw(Canvas canvas) {
    canvas.save();
    canvas.translate(pivotX, pivotY);
    if (angle != 0) canvas.rotate(angle);
    canvas.translate(-paragraph.width / 2, -paragraph.height / 2);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }
}

/// Holds the laid-out dimension-label paragraphs across paints.
///
/// Owned by the canvas state and passed into [AnnotationPainter]. The per-wall
/// / per-room inner-edge geometry and `ui.Paragraph` layout — the most
/// expensive thing the world layers do — is recomputed only when the geometry,
/// colour or font size actually changes. On a pure pan/zoom frame
/// only the world transform differs, so the cached entries are re-drawn as-is
/// instead of being re-laid-out, which is what kept the view laggy.
class AnnotationLabelCache {
  /// Creates an empty cache.
  AnnotationLabelCache();

  List<_LabelEntry>? _entries;
  List<WallSegment>? _walls;
  List<Room>? _rooms;
  Color? _textColor;
  double? _fontSizeWorldMm;
  double? _secondaryFontSizeWorldMm;

  /// Returns the laid-out entries for [painter], rebuilding only when one of
  /// the layout inputs changed since the last call.
  List<_LabelEntry> _resolve(AnnotationPainter painter) {
    final cached = _entries;
    if (cached != null &&
        identical(_walls, painter.walls) &&
        identical(_rooms, painter.rooms) &&
        _textColor == painter.textColor &&
        _fontSizeWorldMm == painter.fontSizeWorldMm &&
        _secondaryFontSizeWorldMm == painter.secondaryFontSizeWorldMm) {
      return cached;
    }
    final entries = painter._buildEntries();
    _entries = entries;
    _walls = painter.walls;
    _rooms = painter.rooms;
    _textColor = painter.textColor;
    _fontSizeWorldMm = painter.fontSizeWorldMm;
    _secondaryFontSizeWorldMm = painter.secondaryFontSizeWorldMm;
    return entries;
  }
}

/// Draws dimension labels on the canvas:
///
/// - Wall length labels at each wall's inner-edge midpoint, showing
///   the EN 12831 *Lichtmaß* length (ADR-017 Rule 5). A small secondary
///   centerline-length sub-label is drawn just outside the primary label
///   for every wall whose centerline differs from its inner edge, so the
///   length the user saw while drawing stays visible after completion
///   (per `agent-ui-ux.md §7.3`).
/// - Room width / height labels for rectangle-eligible rooms
///   (ADR-015), derived from the inner clear polygon.
class AnnotationPainter extends CustomPainter {
  /// Creates an [AnnotationPainter].
  const AnnotationPainter({
    required this.textColor,
    required this.walls,
    required this.rooms,
    this.fontSizeWorldMm = 80.0,
    this.secondaryFontSizeWorldMm = 56.0,
    this.cache,
  });

  /// Colour for annotation text.
  final Color textColor;

  /// All wall segments on the floor.
  final List<WallSegment> walls;

  /// All rooms on the floor.
  final List<Room> rooms;

  /// Primary label font size in world-mm units.
  final double fontSizeWorldMm;

  /// Secondary (centerline) sub-label font size in world-mm units.
  final double secondaryFontSizeWorldMm;

  /// Optional cross-paint cache of laid-out label paragraphs. When supplied,
  /// the layout is reused across pan/zoom frames (transform-only changes).
  final AnnotationLabelCache? cache;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty && rooms.isEmpty) return;

    final entries = cache?._resolve(this) ?? _buildEntries();
    for (final entry in entries) {
      entry.draw(canvas);
    }
  }

  /// Lays out every dimension label once, returning world-positioned entries.
  ///
  /// This is the expensive path (room inner-edge geometry + a `ui.Paragraph`
  /// per wall and room); [AnnotationLabelCache] keeps its result alive across
  /// transform-only repaints.
  List<_LabelEntry> _buildEntries() {
    final entries = <_LabelEntry>[];

    // ADR-001: skip mirror duplicates so each shared wall labels once.
    final drawIds = <String>{};
    for (final w in walls) {
      final mirror = w.mirrorId;
      if (mirror != null && w.id.compareTo(mirror) > 0) continue;
      drawIds.add(w.id);
    }

    final innerEdges = <String, ({Point2D start, Point2D end})>{};
    for (final room in rooms) {
      if (room.polygon.length < 3) continue;
      final roomWalls = walls.where((w) => w.roomId == room.id).toList();
      if (roomWalls.isEmpty) continue;
      innerEdges.addAll(
        GeometryEngine.roomFaceEdges(
          walls: roomWalls,
          roomPolygon: room.polygon,
          side: RoomFaceSide.inner,
        ),
      );
    }

    for (final wall in walls) {
      if (!drawIds.contains(wall.id)) continue;

      final inner = innerEdges[wall.id];
      // Primary label: inner edge length (ADR-017 Rule 5).
      final ({Point2D start, Point2D end}) labelEdge;
      if (inner != null) {
        labelEdge = inner;
      } else {
        // Orphan wall — no room context. Use the centerline.
        labelEdge = (start: wall.startPoint, end: wall.endPoint);
      }
      final innerLen = GeometryEngine.distanceMm(
        labelEdge.start,
        labelEdge.end,
      );
      entries.add(_buildLengthEntry(
        text: '${innerLen.round()}',
        edge: labelEdge,
        outwardSide: _outwardSide(wall, labelEdge),
        fontSize: fontSizeWorldMm,
        offsetMul: 1.0,
      ));

      // Secondary sub-label: centerline length, smaller, offset further
      // outward so it never overlaps the primary label. Drawn for every
      // wall that has a distinct inner edge so the centerline number the
      // user saw while drawing stays visible after completion — the
      // primary switches to the inner *Lichtmaß* length, but the change is
      // explicit rather than a silent jump. Skipped when the wall has no
      // inner edge (the primary is already the centerline) or when the two
      // lengths coincide (nothing to disambiguate).
      if (inner != null) {
        final centerLen = GeometryEngine.distanceMm(
          wall.startPoint,
          wall.endPoint,
        );
        if ((centerLen - innerLen).abs() >= 1.0) {
          entries.add(_buildLengthEntry(
            text: '${centerLen.round()} (CL)',
            edge: labelEdge,
            outwardSide: _outwardSide(wall, labelEdge),
            fontSize: secondaryFontSizeWorldMm,
            offsetMul: 2.4,
          ));
        }
      }
    }

    // Room dimension labels (ADR-015): inner-clear width × height for
    // rectangle-eligible rooms.
    for (final room in rooms) {
      if (room.polygon.length < 3) continue;
      // Rectangle-eligible even when an edge is split into collinear walls by
      // an attached adjacent room (ADR-003): the centerline polygon still
      // collapses to 4 axis-aligned corners. A strict `walls.length == 4`
      // gate would drop the central W×H label for such a room.
      if (!polygonRectangleEligible(room.polygon)) continue;
      final roomWalls = walls.where((w) => w.roomId == room.id).toList();
      final offsets = <double>[];
      var matched = true;
      for (var i = 0; i < room.polygon.length; i++) {
        final pa = room.polygon[i];
        final pb = room.polygon[(i + 1) % room.polygon.length];
        WallSegment? m;
        for (final w in roomWalls) {
          if ((_pointEq(w.startPoint, pa) && _pointEq(w.endPoint, pb)) ||
              (_pointEq(w.startPoint, pb) && _pointEq(w.endPoint, pa))) {
            m = w;
            break;
          }
        }
        if (m == null) {
          matched = false;
          break;
        }
        offsets.add(-m.thicknessMm / 2.0);
      }
      if (!matched) continue;
      final inner = GeometryEngine.offsetPolygonPerEdge(
        centerline: room.polygon,
        edgeOffsetsMm: offsets,
      );
      // The centerline is already a (possibly collinear-split) axis-aligned
      // rectangle, so the inner offset — which may carry >4 vertices at a
      // split — is measured by its bounding box.
      if (inner.length < 4) continue;
      var minX = inner.first.x;
      var maxX = inner.first.x;
      var minY = inner.first.y;
      var maxY = inner.first.y;
      for (final p in inner) {
        minX = min(minX, p.x);
        maxX = max(maxX, p.x);
        minY = min(minY, p.y);
        maxY = max(maxY, p.y);
      }
      final widthMm = (maxX - minX).round();
      final heightMm = (maxY - minY).round();
      final cx = (minX + maxX) / 2.0;
      final cy = (minY + maxY) / 2.0;
      entries.add(_buildCenteredEntry(
        text: '$widthMm × $heightMm mm',
        worldX: cx,
        worldY: cy,
        fontSize: fontSizeWorldMm,
      ));
    }

    return entries;
  }

  /// Returns the outward-normal direction of the wall relative to its
  /// owning room, expressed as a unit vector. Used to push labels just
  /// outside the inner edge so they don't overlap the wall body.
  ({double x, double y}) _outwardSide(
    WallSegment wall,
    ({Point2D start, Point2D end}) edge,
  ) {
    final dx = edge.end.x - edge.start.x;
    final dy = edge.end.y - edge.start.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return (x: 0, y: -1);
    // Compute outward normal using the room polygon winding (same
    // convention as GeometryEngine.offsetPolygonPerEdge). For the
    // inner-edge label we want to draw on the **room-interior side**
    // so the number sits inside the room rather than over the wall.
    final room = rooms.where((r) => r.id == wall.roomId).firstOrNull;
    if (room == null || room.polygon.length < 3) {
      return (x: -dy / len, y: dx / len);
    }
    var signedArea2 = 0.0;
    for (var i = 0; i < room.polygon.length; i++) {
      final a = room.polygon[i];
      final b = room.polygon[(i + 1) % room.polygon.length];
      signedArea2 += a.x * b.y - b.x * a.y;
    }
    final windingSign = signedArea2 > 0 ? 1.0 : -1.0;
    // Inward normal of the wall (room interior side) is `-outward`.
    return (x: -windingSign * dy / len, y: windingSign * dx / len);
  }

  _LabelEntry _buildLengthEntry({
    required String text,
    required ({Point2D start, Point2D end}) edge,
    required ({double x, double y}) outwardSide,
    required double fontSize,
    required double offsetMul,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(color: textColor, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: fontSize * 8));

    final midX = (edge.start.x + edge.end.x) / 2.0;
    final midY = (edge.start.y + edge.end.y) / 2.0;
    final dx = edge.end.x - edge.start.x;
    final dy = edge.end.y - edge.start.y;
    final angle = atan2(dy, dx);
    // Keep labels right-side up: flip 180° when the wall runs right-to-left.
    final keepUp = angle.abs() > pi / 2 ? angle + pi : angle;

    final off = fontSize * offsetMul;
    return _LabelEntry(
      paragraph: paragraph,
      pivotX: midX + outwardSide.x * off,
      pivotY: midY + outwardSide.y * off,
      angle: keepUp,
    );
  }

  _LabelEntry _buildCenteredEntry({
    required String text,
    required double worldX,
    required double worldY,
    required double fontSize,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(color: textColor, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: fontSize * 12));
    return _LabelEntry(
      paragraph: paragraph,
      pivotX: worldX,
      pivotY: worldY,
      angle: 0,
    );
  }

  bool _pointEq(Point2D a, Point2D b) =>
      (a.x - b.x).abs() <= 1.0 && (a.y - b.y).abs() <= 1.0;

  /// Whether [vertices] form an axis-aligned 4-vertex rectangle within
  /// 1 mm tolerance.
  /// True when [polygon] (a centerline loop) is an axis-aligned rectangle,
  /// tolerating collinear "split" vertices (180° straight points) left when an
  /// adjacent room splits a shared wall (ADR-003). A vertex is a true corner
  /// only where a horizontal and a vertical edge meet; the true corners must
  /// be exactly 4, spanning 2 distinct x-values and 2 distinct y-values.
  @visibleForTesting
  static bool polygonRectangleEligible(List<Point2D> polygon) {
    const tol = 1.0;
    final n = polygon.length;
    if (n < 4) return false;

    bool horizontalEdge(int i) =>
        (polygon[i].y - polygon[(i + 1) % n].y).abs() < tol;

    // Every edge must be axis-aligned and non-degenerate.
    for (var i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      final dx = (a.x - b.x).abs();
      final dy = (a.y - b.y).abs();
      if (dx >= tol && dy >= tol) return false; // diagonal
      if (dx < tol && dy < tol) return false; // zero-length
    }

    final corners = <Point2D>[];
    for (var i = 0; i < n; i++) {
      // The edge ending at vertex i vs the edge starting at it: a true corner
      // changes orientation; a collinear split keeps it.
      if (horizontalEdge((i - 1 + n) % n) != horizontalEdge(i)) {
        corners.add(polygon[i]);
      }
    }
    if (corners.length != 4) return false;

    final xs = <double>[];
    final ys = <double>[];
    for (final c in corners) {
      if (!xs.any((v) => (v - c.x).abs() < tol)) xs.add(c.x);
      if (!ys.any((v) => (v - c.y).abs() < tol)) ys.add(c.y);
    }
    return xs.length == 2 && ys.length == 2;
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    if (oldDelegate.textColor != textColor) return true;
    if (oldDelegate.fontSizeWorldMm != fontSizeWorldMm) return true;
    if (oldDelegate.secondaryFontSizeWorldMm !=
        secondaryFontSizeWorldMm) {
      return true;
    }
    if (!identical(oldDelegate.walls, walls)) {
      if (oldDelegate.walls.length != walls.length) return true;
      for (var i = 0; i < walls.length; i++) {
        final a = walls[i];
        final b = oldDelegate.walls[i];
        if (a.id != b.id ||
            a.startPoint != b.startPoint ||
            a.endPoint != b.endPoint ||
            a.thicknessMm != b.thicknessMm ||
            a.anchorMode != b.anchorMode ||
            a.mirrorId != b.mirrorId) {
          return true;
        }
      }
    }
    if (!identical(oldDelegate.rooms, rooms)) return true;
    return false;
  }
}
