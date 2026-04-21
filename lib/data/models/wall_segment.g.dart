// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wall_segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WallSegment _$WallSegmentFromJson(Map<String, dynamic> json) => _WallSegment(
  id: json['id'] as String,
  roomId: json['roomId'] as String,
  startPoint: Point2D.fromJson(json['startPoint'] as Map<String, dynamic>),
  endPoint: Point2D.fromJson(json['endPoint'] as Map<String, dynamic>),
  wallType:
      $enumDecodeNullable(_$WallTypeEnumMap, json['wallType']) ??
      WallType.exterior,
  constructionId: json['constructionId'] as String?,
  adjacentRoomId: json['adjacentRoomId'] as String?,
  orientation:
      $enumDecodeNullable(_$CardinalDirectionEnumMap, json['orientation']) ??
      CardinalDirection.north,
  mirrorId: json['mirrorId'] as String?,
);

Map<String, dynamic> _$WallSegmentToJson(_WallSegment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'startPoint': instance.startPoint,
      'endPoint': instance.endPoint,
      'wallType': _$WallTypeEnumMap[instance.wallType]!,
      'constructionId': instance.constructionId,
      'adjacentRoomId': instance.adjacentRoomId,
      'orientation': _$CardinalDirectionEnumMap[instance.orientation]!,
      'mirrorId': instance.mirrorId,
    };

const _$WallTypeEnumMap = {
  WallType.exterior: 'exterior',
  WallType.interior: 'interior',
  WallType.partition: 'partition',
};

const _$CardinalDirectionEnumMap = {
  CardinalDirection.north: 'north',
  CardinalDirection.northEast: 'northEast',
  CardinalDirection.east: 'east',
  CardinalDirection.southEast: 'southEast',
  CardinalDirection.south: 'south',
  CardinalDirection.southWest: 'southWest',
  CardinalDirection.west: 'west',
  CardinalDirection.northWest: 'northWest',
};
