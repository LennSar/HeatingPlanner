// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_element.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WindowElement {

/// UUID v4 primary key.
 String get id;/// UUID of the parent [WallSegment].
 String get wallSegmentId;/// Distance from the wall's start point to the window's left edge, in mm.
 double get positionOnWallMm;/// Opening width in millimetres. Range: 300–5000.
 int get widthMm;/// Opening height in millimetres. Range: 300–3000.
 int get heightMm;/// Sill height above finished floor level, in millimetres. Range: 0–2500.
 int get sillHeightMm;/// Thermal transmittance of the glazing unit in W/(m²·K). Range: 0.5–6.0.
 double get uValue;
/// Create a copy of WindowElement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowElementCopyWith<WindowElement> get copyWith => _$WindowElementCopyWithImpl<WindowElement>(this as WindowElement, _$identity);

  /// Serializes this WindowElement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowElement&&(identical(other.id, id) || other.id == id)&&(identical(other.wallSegmentId, wallSegmentId) || other.wallSegmentId == wallSegmentId)&&(identical(other.positionOnWallMm, positionOnWallMm) || other.positionOnWallMm == positionOnWallMm)&&(identical(other.widthMm, widthMm) || other.widthMm == widthMm)&&(identical(other.heightMm, heightMm) || other.heightMm == heightMm)&&(identical(other.sillHeightMm, sillHeightMm) || other.sillHeightMm == sillHeightMm)&&(identical(other.uValue, uValue) || other.uValue == uValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,wallSegmentId,positionOnWallMm,widthMm,heightMm,sillHeightMm,uValue);

@override
String toString() {
  return 'WindowElement(id: $id, wallSegmentId: $wallSegmentId, positionOnWallMm: $positionOnWallMm, widthMm: $widthMm, heightMm: $heightMm, sillHeightMm: $sillHeightMm, uValue: $uValue)';
}


}

/// @nodoc
abstract mixin class $WindowElementCopyWith<$Res>  {
  factory $WindowElementCopyWith(WindowElement value, $Res Function(WindowElement) _then) = _$WindowElementCopyWithImpl;
@useResult
$Res call({
 String id, String wallSegmentId, double positionOnWallMm, int widthMm, int heightMm, int sillHeightMm, double uValue
});




}
/// @nodoc
class _$WindowElementCopyWithImpl<$Res>
    implements $WindowElementCopyWith<$Res> {
  _$WindowElementCopyWithImpl(this._self, this._then);

  final WindowElement _self;
  final $Res Function(WindowElement) _then;

/// Create a copy of WindowElement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? wallSegmentId = null,Object? positionOnWallMm = null,Object? widthMm = null,Object? heightMm = null,Object? sillHeightMm = null,Object? uValue = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallSegmentId: null == wallSegmentId ? _self.wallSegmentId : wallSegmentId // ignore: cast_nullable_to_non_nullable
as String,positionOnWallMm: null == positionOnWallMm ? _self.positionOnWallMm : positionOnWallMm // ignore: cast_nullable_to_non_nullable
as double,widthMm: null == widthMm ? _self.widthMm : widthMm // ignore: cast_nullable_to_non_nullable
as int,heightMm: null == heightMm ? _self.heightMm : heightMm // ignore: cast_nullable_to_non_nullable
as int,sillHeightMm: null == sillHeightMm ? _self.sillHeightMm : sillHeightMm // ignore: cast_nullable_to_non_nullable
as int,uValue: null == uValue ? _self.uValue : uValue // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowElement].
extension WindowElementPatterns on WindowElement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowElement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowElement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowElement value)  $default,){
final _that = this;
switch (_that) {
case _WindowElement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowElement value)?  $default,){
final _that = this;
switch (_that) {
case _WindowElement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String wallSegmentId,  double positionOnWallMm,  int widthMm,  int heightMm,  int sillHeightMm,  double uValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowElement() when $default != null:
return $default(_that.id,_that.wallSegmentId,_that.positionOnWallMm,_that.widthMm,_that.heightMm,_that.sillHeightMm,_that.uValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String wallSegmentId,  double positionOnWallMm,  int widthMm,  int heightMm,  int sillHeightMm,  double uValue)  $default,) {final _that = this;
switch (_that) {
case _WindowElement():
return $default(_that.id,_that.wallSegmentId,_that.positionOnWallMm,_that.widthMm,_that.heightMm,_that.sillHeightMm,_that.uValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String wallSegmentId,  double positionOnWallMm,  int widthMm,  int heightMm,  int sillHeightMm,  double uValue)?  $default,) {final _that = this;
switch (_that) {
case _WindowElement() when $default != null:
return $default(_that.id,_that.wallSegmentId,_that.positionOnWallMm,_that.widthMm,_that.heightMm,_that.sillHeightMm,_that.uValue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowElement implements WindowElement {
  const _WindowElement({required this.id, required this.wallSegmentId, required this.positionOnWallMm, this.widthMm = 1200, this.heightMm = 1400, this.sillHeightMm = 900, this.uValue = 1.3});
  factory _WindowElement.fromJson(Map<String, dynamic> json) => _$WindowElementFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the parent [WallSegment].
@override final  String wallSegmentId;
/// Distance from the wall's start point to the window's left edge, in mm.
@override final  double positionOnWallMm;
/// Opening width in millimetres. Range: 300–5000.
@override@JsonKey() final  int widthMm;
/// Opening height in millimetres. Range: 300–3000.
@override@JsonKey() final  int heightMm;
/// Sill height above finished floor level, in millimetres. Range: 0–2500.
@override@JsonKey() final  int sillHeightMm;
/// Thermal transmittance of the glazing unit in W/(m²·K). Range: 0.5–6.0.
@override@JsonKey() final  double uValue;

/// Create a copy of WindowElement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowElementCopyWith<_WindowElement> get copyWith => __$WindowElementCopyWithImpl<_WindowElement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowElementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowElement&&(identical(other.id, id) || other.id == id)&&(identical(other.wallSegmentId, wallSegmentId) || other.wallSegmentId == wallSegmentId)&&(identical(other.positionOnWallMm, positionOnWallMm) || other.positionOnWallMm == positionOnWallMm)&&(identical(other.widthMm, widthMm) || other.widthMm == widthMm)&&(identical(other.heightMm, heightMm) || other.heightMm == heightMm)&&(identical(other.sillHeightMm, sillHeightMm) || other.sillHeightMm == sillHeightMm)&&(identical(other.uValue, uValue) || other.uValue == uValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,wallSegmentId,positionOnWallMm,widthMm,heightMm,sillHeightMm,uValue);

@override
String toString() {
  return 'WindowElement(id: $id, wallSegmentId: $wallSegmentId, positionOnWallMm: $positionOnWallMm, widthMm: $widthMm, heightMm: $heightMm, sillHeightMm: $sillHeightMm, uValue: $uValue)';
}


}

/// @nodoc
abstract mixin class _$WindowElementCopyWith<$Res> implements $WindowElementCopyWith<$Res> {
  factory _$WindowElementCopyWith(_WindowElement value, $Res Function(_WindowElement) _then) = __$WindowElementCopyWithImpl;
@override @useResult
$Res call({
 String id, String wallSegmentId, double positionOnWallMm, int widthMm, int heightMm, int sillHeightMm, double uValue
});




}
/// @nodoc
class __$WindowElementCopyWithImpl<$Res>
    implements _$WindowElementCopyWith<$Res> {
  __$WindowElementCopyWithImpl(this._self, this._then);

  final _WindowElement _self;
  final $Res Function(_WindowElement) _then;

/// Create a copy of WindowElement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? wallSegmentId = null,Object? positionOnWallMm = null,Object? widthMm = null,Object? heightMm = null,Object? sillHeightMm = null,Object? uValue = null,}) {
  return _then(_WindowElement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallSegmentId: null == wallSegmentId ? _self.wallSegmentId : wallSegmentId // ignore: cast_nullable_to_non_nullable
as String,positionOnWallMm: null == positionOnWallMm ? _self.positionOnWallMm : positionOnWallMm // ignore: cast_nullable_to_non_nullable
as double,widthMm: null == widthMm ? _self.widthMm : widthMm // ignore: cast_nullable_to_non_nullable
as int,heightMm: null == heightMm ? _self.heightMm : heightMm // ignore: cast_nullable_to_non_nullable
as int,sillHeightMm: null == sillHeightMm ? _self.sillHeightMm : sillHeightMm // ignore: cast_nullable_to_non_nullable
as int,uValue: null == uValue ? _self.uValue : uValue // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
