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
    );

Map<String, dynamic> _$FlooringMaterialToJson(_FlooringMaterial instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'thermalResistance': instance.thermalResistance,
    };
