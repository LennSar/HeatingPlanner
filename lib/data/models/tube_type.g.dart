// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tube_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TubeType _$TubeTypeFromJson(Map<String, dynamic> json) => _TubeType(
  id: json['id'] as String,
  name: json['name'] as String,
  material: $enumDecode(_$TubeMaterialEnumMap, json['material']),
  outerDiameterMm: (json['outerDiameterMm'] as num?)?.toDouble() ?? 16.0,
  innerDiameterMm: (json['innerDiameterMm'] as num?)?.toDouble() ?? 13.0,
  wallThicknessMm: (json['wallThicknessMm'] as num?)?.toDouble() ?? 1.5,
  thermalConductivity:
      (json['thermalConductivity'] as num?)?.toDouble() ?? 0.35,
  roughness: (json['roughness'] as num?)?.toDouble() ?? 0.007,
  maxOperatingTempC: (json['maxOperatingTempC'] as num?)?.toDouble() ?? 60.0,
  maxOperatingPressure:
      (json['maxOperatingPressure'] as num?)?.toDouble() ?? 6.0,
);

Map<String, dynamic> _$TubeTypeToJson(_TubeType instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'material': _$TubeMaterialEnumMap[instance.material]!,
  'outerDiameterMm': instance.outerDiameterMm,
  'innerDiameterMm': instance.innerDiameterMm,
  'wallThicknessMm': instance.wallThicknessMm,
  'thermalConductivity': instance.thermalConductivity,
  'roughness': instance.roughness,
  'maxOperatingTempC': instance.maxOperatingTempC,
  'maxOperatingPressure': instance.maxOperatingPressure,
};

const _$TubeMaterialEnumMap = {
  TubeMaterial.peRt: 'peRt',
  TubeMaterial.peXa: 'peXa',
  TubeMaterial.peXb: 'peXb',
  TubeMaterial.peXc: 'peXc',
  TubeMaterial.pb: 'pb',
  TubeMaterial.copper: 'copper',
  TubeMaterial.multiLayer: 'multiLayer',
};
