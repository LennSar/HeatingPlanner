// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MaterialEntry _$MaterialEntryFromJson(Map<String, dynamic> json) =>
    _MaterialEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      lambdaDefault: (json['lambdaDefault'] as num).toDouble(),
      densityDefault: (json['densityDefault'] as num).toDouble(),
      specificHeatDefault: (json['specificHeatDefault'] as num).toDouble(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );

Map<String, dynamic> _$MaterialEntryToJson(_MaterialEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'lambdaDefault': instance.lambdaDefault,
      'densityDefault': instance.densityDefault,
      'specificHeatDefault': instance.specificHeatDefault,
      'isBuiltIn': instance.isBuiltIn,
    };
