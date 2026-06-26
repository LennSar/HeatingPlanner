// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecentDocument _$RecentDocumentFromJson(Map<String, dynamic> json) =>
    _RecentDocument(
      path: json['path'] as String,
      name: json['name'] as String,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$RecentDocumentToJson(_RecentDocument instance) =>
    <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
