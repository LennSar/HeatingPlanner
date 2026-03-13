import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory project-level settings that drive heat-demand calculations.
///
/// Acts as the authoritative source for [designOutdoorTempCProvider],
/// [defaultIndoorTempCProvider], and [floorHeightMmProvider] while the
/// database repository is a stub.
/// When the project repository is wired (Phase ≥ 2) this notifier will be
/// initialised from the persisted [Project] and changes will be saved back.
@immutable
class ProjectSettings {
  /// Creates a [ProjectSettings] with the given values.
  const ProjectSettings({
    this.designOutdoorTempC = -12.0,
    this.defaultIndoorTempC = 20.0,
    this.floorHeightMm = 2600,
  });

  /// Outdoor design temperature (°C). Valid range: −50 to +10.
  final double designOutdoorTempC;

  /// Default indoor temperature applied to new rooms (°C). Range: 15 to 30.
  final double defaultIndoorTempC;

  /// Default floor-to-ceiling height in mm. Range: 2000 to 6000.
  final int floorHeightMm;

  /// Returns a copy with updated fields.
  ProjectSettings copyWith({
    double? designOutdoorTempC,
    double? defaultIndoorTempC,
    int? floorHeightMm,
  }) {
    return ProjectSettings(
      designOutdoorTempC:
          designOutdoorTempC ?? this.designOutdoorTempC,
      defaultIndoorTempC:
          defaultIndoorTempC ?? this.defaultIndoorTempC,
      floorHeightMm: floorHeightMm ?? this.floorHeightMm,
    );
  }
}

/// Manages [ProjectSettings] for the currently active project.
class ProjectSettingsNotifier
    extends Notifier<ProjectSettings> {
  @override
  ProjectSettings build() => const ProjectSettings();

  /// Set the outdoor design temperature (clamped to −50…+10 °C).
  void setDesignOutdoorTempC(double value) {
    state = state.copyWith(
      designOutdoorTempC: value.clamp(-50.0, 10.0),
    );
  }

  /// Set the default indoor temperature (clamped to 15…30 °C).
  void setDefaultIndoorTempC(double value) {
    state = state.copyWith(
      defaultIndoorTempC: value.clamp(15.0, 30.0),
    );
  }

  /// Set the default floor height (clamped to 2000…6000 mm).
  void setFloorHeightMm(int value) {
    state = state.copyWith(
      floorHeightMm: value.clamp(2000, 6000),
    );
  }
}

/// Provider for in-memory project-level temperature settings.
final projectSettingsProvider =
    NotifierProvider<ProjectSettingsNotifier, ProjectSettings>(
  ProjectSettingsNotifier.new,
);

/// Outdoor design temperature (°C) used in heat-demand calculations.
///
/// Derived from [projectSettingsProvider]. When the project repository is
/// wired, this will instead watch the persisted
/// [Project.designOutdoorTempC].
final designOutdoorTempCProvider = Provider<double>(
  (ref) =>
      ref.watch(projectSettingsProvider).designOutdoorTempC,
);

/// Default indoor temperature for new rooms (°C).
///
/// Derived from [projectSettingsProvider]. Use when creating a new room
/// to pre-fill its target temperature.
final defaultIndoorTempCProvider = Provider<double>(
  (ref) =>
      ref.watch(projectSettingsProvider).defaultIndoorTempC,
);

/// Default floor-to-ceiling height (mm).
///
/// Derived from [projectSettingsProvider]. Used as the default
/// [HeatingZone.heightMm] for wall heating zones and for the
/// project summary panel.
final floorHeightMmProvider = Provider<int>(
  (ref) => ref.watch(projectSettingsProvider).floorHeightMm,
);
