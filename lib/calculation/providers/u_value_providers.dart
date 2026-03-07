// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/construction_repository.dart';
import '../engines/thermal_engine.dart';

/// U-value (W/(m²·K)) for a [WallConstruction] by [constructionId].
///
/// EN ISO 6946: U = 1 / (R_si + Σ(d_i / λ_i) + R_se)
///
/// Layers are sorted by [MaterialLayer.sortOrder] (outside → inside)
/// before being passed to [ThermalEngine.uValue].
///
/// Returns [double.nan] if the construction or its layers are missing,
/// still loading, or [ThermalEngine.uValue] rejects the inputs.
///
/// Depends on [constructionProvider] and [layersProvider].
final uValueProvider =
    Provider.family<double, String>((ref, constructionId) {
  return ref
      .watch(constructionProvider(constructionId))
      .when(
        data: (construction) {
          if (construction == null) return double.nan;

          return ref
              .watch(layersProvider(constructionId))
              .when(
                data: (layers) {
                  if (layers.isEmpty) return double.nan;
                  final sorted = [...layers]
                    ..sort(
                      (a, b) =>
                          a.sortOrder.compareTo(b.sortOrder),
                    );
                  return ThermalEngine.uValue(
                    layerThicknessesMm: sorted
                        .map((l) => l.thicknessMm)
                        .toList(),
                    layerLambdas: sorted
                        .map((l) => l.thermalConductivity)
                        .toList(),
                    rsi: construction.rsi,
                    rse: construction.rse,
                  );
                },
                loading: () => double.nan,
                error: (_, __) => double.nan,
              );
        },
        loading: () => double.nan,
        error: (_, __) => double.nan,
      );
});
