// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

// TODO(hvac): implement zoneHeatOutputProvider(zoneId) and
// zoneSurfaceTempProvider(zoneId) using HeatingOutputEngine.
