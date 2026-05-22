// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeoLocation _$GeoLocationFromJson(Map<String, dynamic> json) => _GeoLocation(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  cityName: json['cityName'] as String?,
);

Map<String, dynamic> _$GeoLocationToJson(_GeoLocation instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'cityName': instance.cityName,
    };

_Project _$ProjectFromJson(Map<String, dynamic> json) => _Project(
  id: json['id'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
  designOutdoorTempC: (json['designOutdoorTempC'] as num?)?.toDouble() ?? -12.0,
  defaultIndoorTempC: (json['defaultIndoorTempC'] as num?)?.toDouble() ?? 20.0,
  floorHeightMm: (json['floorHeightMm'] as num?)?.toInt() ?? 2600,
  unheatedSpaceTempC: (json['unheatedSpaceTempC'] as num?)?.toDouble() ?? 10.0,
  defaultExteriorWallThicknessMm:
      (json['defaultExteriorWallThicknessMm'] as num?)?.toInt() ?? 240,
  defaultInteriorWallThicknessMm:
      (json['defaultInteriorWallThicknessMm'] as num?)?.toInt() ?? 120,
  defaultPartitionWallThicknessMm:
      (json['defaultPartitionWallThicknessMm'] as num?)?.toInt() ?? 100,
  location: json['location'] == null
      ? null
      : GeoLocation.fromJson(json['location'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt.toIso8601String(),
  'designOutdoorTempC': instance.designOutdoorTempC,
  'defaultIndoorTempC': instance.defaultIndoorTempC,
  'floorHeightMm': instance.floorHeightMm,
  'unheatedSpaceTempC': instance.unheatedSpaceTempC,
  'defaultExteriorWallThicknessMm': instance.defaultExteriorWallThicknessMm,
  'defaultInteriorWallThicknessMm': instance.defaultInteriorWallThicknessMm,
  'defaultPartitionWallThicknessMm': instance.defaultPartitionWallThicknessMm,
  'location': instance.location,
};
