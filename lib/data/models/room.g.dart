// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Room _$RoomFromJson(Map<String, dynamic> json) => _Room(
  id: json['id'] as String,
  floorId: json['floorId'] as String,
  name: json['name'] as String,
  targetTempC: (json['targetTempC'] as num?)?.toDouble() ?? 20.0,
  airChangeRate: (json['airChangeRate'] as num?)?.toDouble() ?? 0.5,
  polygon:
      (json['polygon'] as List<dynamic>?)
          ?.map((e) => Point2D.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$RoomToJson(_Room instance) => <String, dynamic>{
  'id': instance.id,
  'floorId': instance.floorId,
  'name': instance.name,
  'targetTempC': instance.targetTempC,
  'airChangeRate': instance.airChangeRate,
  'polygon': instance.polygon,
};
