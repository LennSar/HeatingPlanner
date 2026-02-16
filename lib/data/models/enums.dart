/// Wall thermal and structural classification.
enum WallType { exterior, interior, partition }

/// Eight-point compass orientation, derived from wall segment geometry.
enum CardinalDirection {
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
  northWest;

  /// Returns the [CardinalDirection] closest to [degrees].
  ///
  /// Uses the convention 0° = east, angles increase counter-clockwise
  /// (standard mathematical convention). Values are normalised to [0, 360).
  static CardinalDirection fromAngleDegrees(double degrees) {
    final normalised = degrees % 360;
    final positive = normalised < 0 ? normalised + 360 : normalised;
    // 8 sectors of 45° each; index 0 = east, increasing counter-clockwise.
    final index = ((positive + 22.5) / 45).floor() % 8;
    const order = [
      CardinalDirection.east,
      CardinalDirection.northEast,
      CardinalDirection.north,
      CardinalDirection.northWest,
      CardinalDirection.west,
      CardinalDirection.southWest,
      CardinalDirection.south,
      CardinalDirection.southEast,
    ];
    return order[index];
  }
}

/// Heating system type embedded in a zone.
enum ZoneType { floorHeating, wallHeating }

/// Tube layout pattern within a heating zone.
enum LayoutPattern { meander, spiral, bifilar, counterflow }

/// Pipe material options for heating circuits.
enum TubeMaterial { peRt, peXa, peXb, peXc, pb, copper, multiLayer }

/// Severity level for validation messages.
enum WarningSeverity { error, warning, info }

/// Active drawing tool on the canvas.
enum DrawingTool {
  select,
  drawWall,
  placeWindow,
  placeDoor,
  drawZone,
  placeDistributor,
  routePipe,
  measure,
}
