// AnnotationPainter.polygonRectangleEligible — gates the central "W × H mm"
// room-dimension label. It must accept a rectangle whose edge has been split
// into collinear walls when an adjacent room is attached (ADR-003), so the
// label does not disappear, while still rejecting genuine non-rectangles.

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/ui/canvas/painters/annotation_painter.dart';

void main() {
  test('plain axis-aligned rectangle is eligible', () {
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 0),
        Point2D(x: 4000, y: 4000),
        Point2D(x: 0, y: 4000),
      ]),
      isTrue,
    );
  });

  test('rectangle with a collinear split vertex on one edge is eligible', () {
    // Bottom edge split at (2000,4000) when a smaller room was attached.
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 0),
        Point2D(x: 4000, y: 4000),
        Point2D(x: 2000, y: 4000), // collinear mid-edge point
        Point2D(x: 0, y: 4000),
      ]),
      isTrue,
    );
  });

  test('rectangle with collinear splits on two edges is eligible', () {
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 2000, y: 0), // split on top
        Point2D(x: 4000, y: 0),
        Point2D(x: 4000, y: 4000),
        Point2D(x: 2000, y: 4000), // split on bottom
        Point2D(x: 0, y: 4000),
      ]),
      isTrue,
    );
  });

  test('L-shape (six true corners) is not eligible', () {
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 5000, y: 0),
        Point2D(x: 5000, y: 2000),
        Point2D(x: 2500, y: 2000),
        Point2D(x: 2500, y: 4000),
        Point2D(x: 0, y: 4000),
      ]),
      isFalse,
    );
  });

  test('a diagonal edge is not eligible', () {
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 500), // diagonal
        Point2D(x: 4000, y: 4000),
        Point2D(x: 0, y: 4000),
      ]),
      isFalse,
    );
  });

  test('fewer than 3 vertices is not eligible', () {
    expect(
      AnnotationPainter.polygonRectangleEligible(const [
        Point2D(x: 0, y: 0),
        Point2D(x: 4000, y: 0),
      ]),
      isFalse,
    );
  });
}
