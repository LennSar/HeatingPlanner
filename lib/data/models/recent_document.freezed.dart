// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecentDocument {

/// Absolute file-system path of the `.hsp` file.
 String get path;/// Cached project name, shown on the project card.
 String get name;/// Cached timestamp of the last save, shown on the project card.
 DateTime get modifiedAt;
/// Create a copy of RecentDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentDocumentCopyWith<RecentDocument> get copyWith => _$RecentDocumentCopyWithImpl<RecentDocument>(this as RecentDocument, _$identity);

  /// Serializes this RecentDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentDocument&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,modifiedAt);

@override
String toString() {
  return 'RecentDocument(path: $path, name: $name, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $RecentDocumentCopyWith<$Res>  {
  factory $RecentDocumentCopyWith(RecentDocument value, $Res Function(RecentDocument) _then) = _$RecentDocumentCopyWithImpl;
@useResult
$Res call({
 String path, String name, DateTime modifiedAt
});




}
/// @nodoc
class _$RecentDocumentCopyWithImpl<$Res>
    implements $RecentDocumentCopyWith<$Res> {
  _$RecentDocumentCopyWithImpl(this._self, this._then);

  final RecentDocument _self;
  final $Res Function(RecentDocument) _then;

/// Create a copy of RecentDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? name = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RecentDocument].
extension RecentDocumentPatterns on RecentDocument {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentDocument() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentDocument value)  $default,){
final _that = this;
switch (_that) {
case _RecentDocument():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentDocument value)?  $default,){
final _that = this;
switch (_that) {
case _RecentDocument() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String name,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentDocument() when $default != null:
return $default(_that.path,_that.name,_that.modifiedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String name,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _RecentDocument():
return $default(_that.path,_that.name,_that.modifiedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String name,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _RecentDocument() when $default != null:
return $default(_that.path,_that.name,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecentDocument implements RecentDocument {
  const _RecentDocument({required this.path, required this.name, required this.modifiedAt});
  factory _RecentDocument.fromJson(Map<String, dynamic> json) => _$RecentDocumentFromJson(json);

/// Absolute file-system path of the `.hsp` file.
@override final  String path;
/// Cached project name, shown on the project card.
@override final  String name;
/// Cached timestamp of the last save, shown on the project card.
@override final  DateTime modifiedAt;

/// Create a copy of RecentDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentDocumentCopyWith<_RecentDocument> get copyWith => __$RecentDocumentCopyWithImpl<_RecentDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecentDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentDocument&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,modifiedAt);

@override
String toString() {
  return 'RecentDocument(path: $path, name: $name, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$RecentDocumentCopyWith<$Res> implements $RecentDocumentCopyWith<$Res> {
  factory _$RecentDocumentCopyWith(_RecentDocument value, $Res Function(_RecentDocument) _then) = __$RecentDocumentCopyWithImpl;
@override @useResult
$Res call({
 String path, String name, DateTime modifiedAt
});




}
/// @nodoc
class __$RecentDocumentCopyWithImpl<$Res>
    implements _$RecentDocumentCopyWith<$Res> {
  __$RecentDocumentCopyWithImpl(this._self, this._then);

  final _RecentDocument _self;
  final $Res Function(_RecentDocument) _then;

/// Create a copy of RecentDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? name = null,Object? modifiedAt = null,}) {
  return _then(_RecentDocument(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
