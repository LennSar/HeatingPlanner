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

/// Applicable surface type for a [FlooringMaterial].
///
/// Used to filter materials in the properties panel so only
/// appropriate choices are shown for each zone type.
enum SurfaceType { floor, wall, both }

/// Supply and return run insulation strategy (ADR-008).
enum SupplyPipeInsulationType {
  /// Pipe embedded directly in screed — full heat output to transit room.
  none,

  /// Pipe in corrugated PE conduit (Wellrohr) in screed — ~25–30 % residual heat.
  corrugatedConduit,

  /// Pipe routed inside the insulation layer below the screed — no heat output.
  insulationLayer,
}

/// Active drawing tool on the canvas.
enum DrawingTool {
  select,
  drawWall,
  placeWindow,
  placeDoor,
  drawZone,

  /// Place a wall heating zone by clicking a wall segment.
  drawWallZone,
  placeDistributor,
  routePipe,
  measure,
}

/// Boundary condition for a room's floor or ceiling slab.
///
/// Determines the correction factor applied in the floor/ceiling
/// heat loss calculation (EN 12831 / ISO 13370).
enum BoundaryCondition {
  /// Direct outdoor air contact (e.g. flat roof, exposed soffit).
  /// Correction factor: 1.0.
  exterior,

  /// In contact with ground — simplified 0.6 factor (ISO 13370).
  ground,

  /// Adjacent unheated space (attic, garage, crawlspace, cellar).
  /// Correction factor supplied by the user.
  unheatedSpace,

  /// Adjacent heated room at the same target temperature.
  /// Correction factor: 0.0 (no heat loss).
  interior,
}
