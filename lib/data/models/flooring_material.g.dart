// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flooring_material.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FlooringMaterial _$FlooringMaterialFromJson(Map<String, dynamic> json) =>
    _FlooringMaterial(
      id: json['id'] as String,
      name: json['name'] as String,
      thermalResistance: (json['thermalResistance'] as num).toDouble(),
      surfaceType:
          $enumDecodeNullable(_$SurfaceTypeEnumMap, json['surfaceType']) ??
          SurfaceType.floor,
    );

Map<String, dynamic> _$FlooringMaterialToJson(_FlooringMaterial instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'thermalResistance': instance.thermalResistance,
      'surfaceType': _$SurfaceTypeEnumMap[instance.surfaceType]!,
    };

const _$SurfaceTypeEnumMap = {
  SurfaceType.floor: 'floor',
  SurfaceType.wall: 'wall',
  SurfaceType.both: 'both',
};
