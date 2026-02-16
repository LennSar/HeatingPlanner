// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'door.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Door _$DoorFromJson(Map<String, dynamic> json) => _Door(
  id: json['id'] as String,
  wallSegmentId: json['wallSegmentId'] as String,
  positionOnWallMm: (json['positionOnWallMm'] as num).toDouble(),
  widthMm: (json['widthMm'] as num?)?.toInt() ?? 900,
  heightMm: (json['heightMm'] as num?)?.toInt() ?? 2100,
  sillHeightMm: (json['sillHeightMm'] as num?)?.toInt() ?? 0,
  uValue: (json['uValue'] as num?)?.toDouble() ?? 2.0,
);

Map<String, dynamic> _$DoorToJson(_Door instance) => <String, dynamic>{
  'id': instance.id,
  'wallSegmentId': instance.wallSegmentId,
  'positionOnWallMm': instance.positionOnWallMm,
  'widthMm': instance.widthMm,
  'heightMm': instance.heightMm,
  'sillHeightMm': instance.sillHeightMm,
  'uValue': instance.uValue,
};
