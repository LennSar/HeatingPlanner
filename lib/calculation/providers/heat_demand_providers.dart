// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

// TODO(hvac): implement roomHeatDemandProvider(roomId) and
// buildingHeatDemandProvider(projectId) using ThermalEngine.
