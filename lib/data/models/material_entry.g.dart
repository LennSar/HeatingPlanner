// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MaterialEntry _$MaterialEntryFromJson(Map<String, dynamic> json) =>
    _MaterialEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      nameDe: json['nameDe'] as String?,
      categoryPath: (json['categoryPath'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lambdaDefault: (json['lambdaDefault'] as num).toDouble(),
      densityDefault: (json['densityDefault'] as num).toDouble(),
      specificHeatDefault: (json['specificHeatDefault'] as num).toDouble(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );

Map<String, dynamic> _$MaterialEntryToJson(_MaterialEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameDe': instance.nameDe,
      'categoryPath': instance.categoryPath,
      'lambdaDefault': instance.lambdaDefault,
      'densityDefault': instance.densityDefault,
      'specificHeatDefault': instance.specificHeatDefault,
      'isBuiltIn': instance.isBuiltIn,
    };
