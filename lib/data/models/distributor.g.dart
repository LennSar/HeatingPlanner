// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'distributor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Distributor _$DistributorFromJson(Map<String, dynamic> json) => _Distributor(
  id: json['id'] as String,
  floorId: json['floorId'] as String,
  position: Point2D.fromJson(json['position'] as Map<String, dynamic>),
  supplyTempC: (json['supplyTempC'] as num?)?.toDouble() ?? 35.0,
  returnTempC: (json['returnTempC'] as num?)?.toDouble() ?? 28.0,
  pumpHeadPa: (json['pumpHeadPa'] as num?)?.toDouble() ?? 25000.0,
);

Map<String, dynamic> _$DistributorToJson(_Distributor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'floorId': instance.floorId,
      'position': instance.position,
      'supplyTempC': instance.supplyTempC,
      'returnTempC': instance.returnTempC,
      'pumpHeadPa': instance.pumpHeadPa,
    };
