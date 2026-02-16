// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Floor _$FloorFromJson(Map<String, dynamic> json) => _Floor(
  id: json['id'] as String,
  name: json['name'] as String,
  level: (json['level'] as num?)?.toInt() ?? 0,
  heightMm: (json['heightMm'] as num?)?.toInt() ?? 2600,
);

Map<String, dynamic> _$FloorToJson(_Floor instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'level': instance.level,
  'heightMm': instance.heightMm,
};
