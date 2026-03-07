// TODO(architect): implement ConstructionRepository wrapping ConstructionDao.
// Exposes wall constructions and material layers as Stream APIs.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/material_layer.dart';
import '../data/models/wall_construction.dart';

/// Reactive stream of a single [WallConstruction] by ID.
///
/// Returns `null` if the construction does not exist.
/// TODO(architect): replace stub with ConstructionDao.watchById.
final constructionProvider =
    StreamProvider.family<WallConstruction?, String>(
  (ref, constructionId) async* {
    yield null;
  },
);

/// Reactive stream of all [MaterialLayer]s for a construction.
///
/// Layers are unordered; consumers must sort by [MaterialLayer.sortOrder].
/// TODO(architect): replace stub with ConstructionDao.watchLayersByConstruction.
final layersProvider =
    StreamProvider.family<List<MaterialLayer>, String>(
  (ref, constructionId) async* {
    yield const [];
  },
);
