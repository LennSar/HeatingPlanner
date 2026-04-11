// RULE: Never modify providers during widget build.
// All mutations happen in response to user actions or via
// ref.listen inside provider definitions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/construction_repository.dart';
import '../engines/thermal_engine.dart';

/// U-value (W/(m²·K)) for a [WallConstruction] by [constructionId].
///
/// Uses [ThermalEngine.uValueCombined] (EN ISO 6946:2017 §6.9) so that
/// inhomogeneous layers with stud bridging are handled correctly.
/// For fully homogeneous constructions the result is identical to the
/// plain series formula.
///
/// Layers are sorted by [MaterialLayer.sortOrder] (outside → inside) and
/// mapped to [LayerSpec]: layers with non-null [MaterialLayer.studWidthMm],
/// [MaterialLayer.studClearGapMm], and [MaterialLayer.studLambda] become
/// [InhomogeneousLayerSpec]; all others become [HomogeneousLayerSpec].
///
/// Returns [double.nan] if the construction or its layers are missing,
/// still loading, or [ThermalEngine.uValueCombined] rejects the inputs.
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
                  final specs = sorted.map((l) {
                    if (l.studWidthMm != null &&
                        l.studClearGapMm != null &&
                        l.studLambda != null) {
                      return InhomogeneousLayerSpec(
                        thicknessMm: l.thicknessMm,
                        lambdaMain: l.thermalConductivity,
                        studWidthMm: l.studWidthMm!,
                        studClearGapMm: l.studClearGapMm!,
                        lambdaStud: l.studLambda!,
                      );
                    }
                    return HomogeneousLayerSpec(
                      thicknessMm: l.thicknessMm,
                      lambda: l.thermalConductivity,
                    );
                  }).toList();
                  return ThermalEngine.uValueCombined(
                    layers: specs,
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
