// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wall_construction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WallConstruction _$WallConstructionFromJson(Map<String, dynamic> json) =>
    _WallConstruction(
      id: json['id'] as String,
      name: json['name'] as String,
      nameDe: json['nameDe'] as String?,
      rsi: (json['rsi'] as num?)?.toDouble() ?? 0.13,
      rse: (json['rse'] as num?)?.toDouble() ?? 0.04,
      isPreset: json['isPreset'] as bool? ?? false,
      isAutoDefault: json['isAutoDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$WallConstructionToJson(_WallConstruction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameDe': instance.nameDe,
      'rsi': instance.rsi,
      'rse': instance.rse,
      'isPreset': instance.isPreset,
      'isAutoDefault': instance.isAutoDefault,
    };
