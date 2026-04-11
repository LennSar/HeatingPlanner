// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_layer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MaterialLayer _$MaterialLayerFromJson(Map<String, dynamic> json) =>
    _MaterialLayer(
      id: json['id'] as String,
      constructionId: json['constructionId'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
      materialId: json['materialId'] as String,
      thicknessMm: (json['thicknessMm'] as num).toDouble(),
      thermalConductivity: (json['thermalConductivity'] as num).toDouble(),
      density: (json['density'] as num).toDouble(),
      specificHeat: (json['specificHeat'] as num).toDouble(),
      studWidthMm: (json['studWidthMm'] as num?)?.toDouble(),
      studClearGapMm: (json['studClearGapMm'] as num?)?.toDouble(),
      studLambda: (json['studLambda'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$MaterialLayerToJson(_MaterialLayer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'constructionId': instance.constructionId,
      'sortOrder': instance.sortOrder,
      'materialId': instance.materialId,
      'thicknessMm': instance.thicknessMm,
      'thermalConductivity': instance.thermalConductivity,
      'density': instance.density,
      'specificHeat': instance.specificHeat,
      'studWidthMm': instance.studWidthMm,
      'studClearGapMm': instance.studClearGapMm,
      'studLambda': instance.studLambda,
    };
