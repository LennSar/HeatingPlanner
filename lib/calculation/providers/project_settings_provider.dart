import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/project_repository.dart';
import '../../repositories/save_state_notifier.dart';

/// In-memory snapshot of the project-level settings fields that drive
/// heat-demand, zone-output, and wall-geometry calculations.
///
/// Derived from the persisted [Project] via [projectSettingsProvider].
@immutable
class ProjectSettings {
  /// Creates a [ProjectSettings] with the given values.
  const ProjectSettings({
    this.designOutdoorTempC = -12.0,
    this.defaultIndoorTempC = 20.0,
    this.floorHeightMm = 2600,
    this.unheatedSpaceTempC = 10.0,
    this.defaultExteriorWallThicknessMm = 240,
    this.defaultInteriorWallThicknessMm = 120,
    this.defaultPartitionWallThicknessMm = 100,
  });

  /// Outdoor design temperature (°C). Valid range: −50 to +10.
  final double designOutdoorTempC;

  /// Default indoor temperature applied to new rooms (°C). Range: 15 to 30.
  final double defaultIndoorTempC;

  /// Default floor-to-ceiling height in mm. Range: 2000 to 6000.
  final int floorHeightMm;

  /// Default temperature of unheated adjacent spaces (°C). Range: 0 to 25.
  ///
  /// Used as the [BoundaryCondition.unheatedSpace] adjacent temperature when
  /// no per-room override is set. Also serves as the default for
  /// [BoundaryCondition.interior] floor/ceiling when no override is set.
  final double unheatedSpaceTempC;

  /// Default total thickness in mm for exterior walls (ADR-017).
  final int defaultExteriorWallThicknessMm;

  /// Default total thickness in mm for interior (shared) walls (ADR-017).
  final int defaultInteriorWallThicknessMm;

  /// Default total thickness in mm for partition walls (ADR-017).
  final int defaultPartitionWallThicknessMm;

  /// Returns a copy with updated fields.
  ProjectSettings copyWith({
    double? designOutdoorTempC,
    double? defaultIndoorTempC,
    int? floorHeightMm,
    double? unheatedSpaceTempC,
    int? defaultExteriorWallThicknessMm,
    int? defaultInteriorWallThicknessMm,
    int? defaultPartitionWallThicknessMm,
  }) {
    return ProjectSettings(
      designOutdoorTempC:
          designOutdoorTempC ?? this.designOutdoorTempC,
      defaultIndoorTempC:
          defaultIndoorTempC ?? this.defaultIndoorTempC,
      floorHeightMm: floorHeightMm ?? this.floorHeightMm,
      unheatedSpaceTempC:
          unheatedSpaceTempC ?? this.unheatedSpaceTempC,
      defaultExteriorWallThicknessMm: defaultExteriorWallThicknessMm ??
          this.defaultExteriorWallThicknessMm,
      defaultInteriorWallThicknessMm: defaultInteriorWallThicknessMm ??
          this.defaultInteriorWallThicknessMm,
      defaultPartitionWallThicknessMm: defaultPartitionWallThicknessMm ??
          this.defaultPartitionWallThicknessMm,
    );
  }
}

/// Manages [ProjectSettings] for the currently active project.
///
/// [build] derives its state from the persisted [Project] via
/// [projectProvider], so the settings are always in sync with
/// SQLite.  Each setter updates the in-memory state optimistically
/// and immediately writes the updated [Project] back via
/// [ProjectRepository.upsertProject].
class ProjectSettingsNotifier
    extends Notifier<ProjectSettings>
    with SaveStateMixin {
  @override
  ProjectSettings build() {
    final projectId = ref.watch(currentProjectIdProvider);
    if (projectId.isEmpty) return const ProjectSettings();

    return ref
            .watch(projectProvider(projectId))
            .whenOrNull(
              data: (project) => project == null
                  ? null
                  : ProjectSettings(
                      designOutdoorTempC:
                          project.designOutdoorTempC,
                      defaultIndoorTempC:
                          project.defaultIndoorTempC,
                      floorHeightMm: project.floorHeightMm,
                      unheatedSpaceTempC:
                          project.unheatedSpaceTempC,
                      defaultExteriorWallThicknessMm:
                          project.defaultExteriorWallThicknessMm,
                      defaultInteriorWallThicknessMm:
                          project.defaultInteriorWallThicknessMm,
                      defaultPartitionWallThicknessMm:
                          project.defaultPartitionWallThicknessMm,
                    ),
            ) ??
        const ProjectSettings();
  }

  /// Set the outdoor design temperature (clamped to −50…+10 °C).
  void setDesignOutdoorTempC(double value) {
    state = state.copyWith(
      designOutdoorTempC: value.clamp(-50.0, 10.0),
    );
    _persist();
  }

  /// Set the default indoor temperature (clamped to 15…30 °C).
  void setDefaultIndoorTempC(double value) {
    state = state.copyWith(
      defaultIndoorTempC: value.clamp(15.0, 30.0),
    );
    _persist();
  }

  /// Set the default floor height (clamped to 2000…6000 mm).
  void setFloorHeightMm(int value) {
    state = state.copyWith(
      floorHeightMm: value.clamp(2000, 6000),
    );
    _persist();
  }

  /// Set the default unheated space temperature (clamped to 0…25 °C).
  void setUnheatedSpaceTempC(double value) {
    state = state.copyWith(
      unheatedSpaceTempC: value.clamp(0.0, 25.0),
    );
    _persist();
  }

  /// Set the default exterior wall thickness in mm (clamped to 50…1000).
  ///
  /// Per ADR-017 Rule 9, every unassigned exterior wall (no
  /// `constructionId`) must have its `thicknessMm` and centerline
  /// re-anchored to follow the new value. Callers are responsible for
  /// invoking the cascade — typically the editor-state notifier's
  /// `recomputeWallsForProjectDefault(WallType.exterior)` — so a single
  /// `UndoRedoService` command can revert the whole change.
  void setDefaultExteriorWallThicknessMm(int value) {
    state = state.copyWith(
      defaultExteriorWallThicknessMm: value.clamp(50, 1000),
    );
    _persist();
  }

  /// Set the default interior (shared) wall thickness in mm (50…1000).
  ///
  /// See [setDefaultExteriorWallThicknessMm] for the cascade contract.
  void setDefaultInteriorWallThicknessMm(int value) {
    state = state.copyWith(
      defaultInteriorWallThicknessMm: value.clamp(50, 1000),
    );
    _persist();
  }

  /// Set the default partition wall thickness in mm (clamped to 50…1000).
  ///
  /// See [setDefaultExteriorWallThicknessMm] for the cascade contract.
  void setDefaultPartitionWallThicknessMm(int value) {
    state = state.copyWith(
      defaultPartitionWallThicknessMm: value.clamp(50, 1000),
    );
    _persist();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Writes the current [state] back to the [Project] row in SQLite.
  ///
  /// No-op when no project is open or the project has not yet loaded.
  void _persist() {
    final projectId = ref.read(currentProjectIdProvider);
    if (projectId.isEmpty) return;
    final project =
        ref.read(projectProvider(projectId)).asData?.value;
    if (project == null) return;

    final updated = project.copyWith(
      designOutdoorTempC: state.designOutdoorTempC,
      defaultIndoorTempC: state.defaultIndoorTempC,
      floorHeightMm: state.floorHeightMm,
      unheatedSpaceTempC: state.unheatedSpaceTempC,
      defaultExteriorWallThicknessMm:
          state.defaultExteriorWallThicknessMm,
      defaultInteriorWallThicknessMm:
          state.defaultInteriorWallThicknessMm,
      defaultPartitionWallThicknessMm:
          state.defaultPartitionWallThicknessMm,
      modifiedAt: DateTime.now(),
    );
    unawaited(
      ref.read(projectRepositoryProvider).upsertProject(updated),
    );
    markProjectDirty();
  }
}

/// Provider for in-memory project-level temperature settings.
///
/// Automatically reflects the persisted [Project] for the currently
/// open project.  Widgets read this provider instead of [projectProvider]
/// so that calculation providers re-evaluate whenever a setting changes.
final projectSettingsProvider =
    NotifierProvider<ProjectSettingsNotifier, ProjectSettings>(
  ProjectSettingsNotifier.new,
);

/// Outdoor design temperature (°C) used in heat-demand calculations.
final designOutdoorTempCProvider = Provider<double>(
  (ref) =>
      ref.watch(projectSettingsProvider).designOutdoorTempC,
);

/// Default indoor temperature for new rooms (°C).
final defaultIndoorTempCProvider = Provider<double>(
  (ref) =>
      ref.watch(projectSettingsProvider).defaultIndoorTempC,
);

/// Default floor-to-ceiling height (mm).
final floorHeightMmProvider = Provider<int>(
  (ref) => ref.watch(projectSettingsProvider).floorHeightMm,
);

/// Default temperature of unheated adjacent spaces (°C).
final unheatedSpaceTempCProvider = Provider<double>(
  (ref) =>
      ref.watch(projectSettingsProvider).unheatedSpaceTempC,
);
