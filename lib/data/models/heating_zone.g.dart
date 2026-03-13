// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heating_zone.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HeatingZone _$HeatingZoneFromJson(Map<String, dynamic> json) => _HeatingZone(
  id: json['id'] as String,
  roomId: json['roomId'] as String,
  zoneType:
      $enumDecodeNullable(_$ZoneTypeEnumMap, json['zoneType']) ??
      ZoneType.floorHeating,
  polygon:
      (json['polygon'] as List<dynamic>?)
          ?.map((e) => Point2D.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  tubeSpacingMm: (json['tubeSpacingMm'] as num?)?.toInt() ?? 150,
  tubeTypeId: json['tubeTypeId'] as String,
  flooringMaterialId: json['flooringMaterialId'] as String,
  borderDistanceMm: (json['borderDistanceMm'] as num?)?.toInt() ?? 100,
  layoutPattern:
      $enumDecodeNullable(_$LayoutPatternEnumMap, json['layoutPattern']) ??
      LayoutPattern.meander,
  circuitId: json['circuitId'] as String?,
  wallSegmentId: json['wallSegmentId'] as String?,
  heightMm: (json['heightMm'] as num?)?.toInt(),
  positionOnWallMm: (json['positionOnWallMm'] as num?)?.toDouble(),
  widthMm: (json['widthMm'] as num?)?.toInt(),
);

Map<String, dynamic> _$HeatingZoneToJson(_HeatingZone instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'zoneType': _$ZoneTypeEnumMap[instance.zoneType]!,
      'polygon': instance.polygon,
      'tubeSpacingMm': instance.tubeSpacingMm,
      'tubeTypeId': instance.tubeTypeId,
      'flooringMaterialId': instance.flooringMaterialId,
      'borderDistanceMm': instance.borderDistanceMm,
      'layoutPattern': _$LayoutPatternEnumMap[instance.layoutPattern]!,
      'circuitId': instance.circuitId,
      'wallSegmentId': instance.wallSegmentId,
      'heightMm': instance.heightMm,
      'positionOnWallMm': instance.positionOnWallMm,
      'widthMm': instance.widthMm,
    };

const _$ZoneTypeEnumMap = {
  ZoneType.floorHeating: 'floorHeating',
  ZoneType.wallHeating: 'wallHeating',
};

const _$LayoutPatternEnumMap = {
  LayoutPattern.meander: 'meander',
  LayoutPattern.spiral: 'spiral',
  LayoutPattern.bifilar: 'bifilar',
  LayoutPattern.counterflow: 'counterflow',
};
