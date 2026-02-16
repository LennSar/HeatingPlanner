import 'package:drift/drift.dart';

/// Drift table definition for [TubeType] entities.
class TubeTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get material => text()();
  RealColumn get outerDiameterMm =>
      real().withDefault(const Constant(16.0))();
  RealColumn get innerDiameterMm =>
      real().withDefault(const Constant(13.0))();
  RealColumn get wallThicknessMm =>
      real().withDefault(const Constant(1.5))();
  RealColumn get thermalConductivity =>
      real().withDefault(const Constant(0.35))();
  RealColumn get roughness =>
      real().withDefault(const Constant(0.007))();
  RealColumn get maxOperatingTempC =>
      real().withDefault(const Constant(60.0))();
  RealColumn get maxOperatingPressure =>
      real().withDefault(const Constant(6.0))();

  @override
  Set<Column> get primaryKey => {id};
}
