// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validation_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ValidationResult _$ValidationResultFromJson(Map<String, dynamic> json) =>
    _ValidationResult(
      severity: $enumDecode(_$WarningSeverityEnumMap, json['severity']),
      elementId: json['elementId'] as String,
      elementType: json['elementType'] as String,
      message: json['message'] as String,
      suggestedFix: json['suggestedFix'] as String?,
    );

Map<String, dynamic> _$ValidationResultToJson(_ValidationResult instance) =>
    <String, dynamic>{
      'severity': _$WarningSeverityEnumMap[instance.severity]!,
      'elementId': instance.elementId,
      'elementType': instance.elementType,
      'message': instance.message,
      'suggestedFix': instance.suggestedFix,
    };

const _$WarningSeverityEnumMap = {
  WarningSeverity.error: 'error',
  WarningSeverity.warning: 'warning',
  WarningSeverity.info: 'info',
};
