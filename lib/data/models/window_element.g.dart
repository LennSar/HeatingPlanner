// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_element.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WindowElement _$WindowElementFromJson(Map<String, dynamic> json) =>
    _WindowElement(
      id: json['id'] as String,
      wallSegmentId: json['wallSegmentId'] as String,
      positionOnWallMm: (json['positionOnWallMm'] as num).toDouble(),
      widthMm: (json['widthMm'] as num?)?.toInt() ?? 1200,
      heightMm: (json['heightMm'] as num?)?.toInt() ?? 1400,
      sillHeightMm: (json['sillHeightMm'] as num?)?.toInt() ?? 900,
      uValue: (json['uValue'] as num?)?.toDouble() ?? 1.3,
    );

Map<String, dynamic> _$WindowElementToJson(_WindowElement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wallSegmentId': instance.wallSegmentId,
      'positionOnWallMm': instance.positionOnWallMm,
      'widthMm': instance.widthMm,
      'heightMm': instance.heightMm,
      'sillHeightMm': instance.sillHeightMm,
      'uValue': instance.uValue,
    };
