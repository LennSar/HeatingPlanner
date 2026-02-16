// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heating_circuit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HeatingCircuit _$HeatingCircuitFromJson(Map<String, dynamic> json) =>
    _HeatingCircuit(
      id: json['id'] as String,
      distributorId: json['distributorId'] as String,
      heatingZoneId: json['heatingZoneId'] as String,
      supplyRoutePath:
          (json['supplyRoutePath'] as List<dynamic>?)
              ?.map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      returnRoutePath:
          (json['returnRoutePath'] as List<dynamic>?)
              ?.map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tubeLengthM: (json['tubeLengthM'] as num?)?.toDouble() ?? 0.0,
      flowRateKgH: (json['flowRateKgH'] as num?)?.toDouble() ?? 0.0,
      pressureLossPa: (json['pressureLossPa'] as num?)?.toDouble() ?? 0.0,
      valveSetting: (json['valveSetting'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$HeatingCircuitToJson(_HeatingCircuit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'distributorId': instance.distributorId,
      'heatingZoneId': instance.heatingZoneId,
      'supplyRoutePath': instance.supplyRoutePath,
      'returnRoutePath': instance.returnRoutePath,
      'tubeLengthM': instance.tubeLengthM,
      'flowRateKgH': instance.flowRateKgH,
      'pressureLossPa': instance.pressureLossPa,
      'valveSetting': instance.valveSetting,
    };
