// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tube_type.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TubeType {

/// UUID v4 primary key.
 String get id;/// Display name (1–100 chars).
 String get name;/// Pipe material.
 TubeMaterial get material;/// Outer diameter in millimetres. Range: 8.0–32.0.
 double get outerDiameterMm;/// Inner (bore) diameter in millimetres. Must be < [outerDiameterMm].
 double get innerDiameterMm;/// Wall thickness in millimetres (may be derived or explicitly set).
 double get wallThicknessMm;/// Thermal conductivity of the pipe wall in W/(m·K).
 double get thermalConductivity;/// Absolute roughness of the bore surface in mm. Range: 0.001–0.1.
 double get roughness;/// Maximum allowable fluid temperature in °C.
 double get maxOperatingTempC;/// Maximum allowable operating pressure in bar.
 double get maxOperatingPressure;
/// Create a copy of TubeType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TubeTypeCopyWith<TubeType> get copyWith => _$TubeTypeCopyWithImpl<TubeType>(this as TubeType, _$identity);

  /// Serializes this TubeType to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TubeType&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.material, material) || other.material == material)&&(identical(other.outerDiameterMm, outerDiameterMm) || other.outerDiameterMm == outerDiameterMm)&&(identical(other.innerDiameterMm, innerDiameterMm) || other.innerDiameterMm == innerDiameterMm)&&(identical(other.wallThicknessMm, wallThicknessMm) || other.wallThicknessMm == wallThicknessMm)&&(identical(other.thermalConductivity, thermalConductivity) || other.thermalConductivity == thermalConductivity)&&(identical(other.roughness, roughness) || other.roughness == roughness)&&(identical(other.maxOperatingTempC, maxOperatingTempC) || other.maxOperatingTempC == maxOperatingTempC)&&(identical(other.maxOperatingPressure, maxOperatingPressure) || other.maxOperatingPressure == maxOperatingPressure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,material,outerDiameterMm,innerDiameterMm,wallThicknessMm,thermalConductivity,roughness,maxOperatingTempC,maxOperatingPressure);

@override
String toString() {
  return 'TubeType(id: $id, name: $name, material: $material, outerDiameterMm: $outerDiameterMm, innerDiameterMm: $innerDiameterMm, wallThicknessMm: $wallThicknessMm, thermalConductivity: $thermalConductivity, roughness: $roughness, maxOperatingTempC: $maxOperatingTempC, maxOperatingPressure: $maxOperatingPressure)';
}


}

/// @nodoc
abstract mixin class $TubeTypeCopyWith<$Res>  {
  factory $TubeTypeCopyWith(TubeType value, $Res Function(TubeType) _then) = _$TubeTypeCopyWithImpl;
@useResult
$Res call({
 String id, String name, TubeMaterial material, double outerDiameterMm, double innerDiameterMm, double wallThicknessMm, double thermalConductivity, double roughness, double maxOperatingTempC, double maxOperatingPressure
});




}
/// @nodoc
class _$TubeTypeCopyWithImpl<$Res>
    implements $TubeTypeCopyWith<$Res> {
  _$TubeTypeCopyWithImpl(this._self, this._then);

  final TubeType _self;
  final $Res Function(TubeType) _then;

/// Create a copy of TubeType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? material = null,Object? outerDiameterMm = null,Object? innerDiameterMm = null,Object? wallThicknessMm = null,Object? thermalConductivity = null,Object? roughness = null,Object? maxOperatingTempC = null,Object? maxOperatingPressure = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,material: null == material ? _self.material : material // ignore: cast_nullable_to_non_nullable
as TubeMaterial,outerDiameterMm: null == outerDiameterMm ? _self.outerDiameterMm : outerDiameterMm // ignore: cast_nullable_to_non_nullable
as double,innerDiameterMm: null == innerDiameterMm ? _self.innerDiameterMm : innerDiameterMm // ignore: cast_nullable_to_non_nullable
as double,wallThicknessMm: null == wallThicknessMm ? _self.wallThicknessMm : wallThicknessMm // ignore: cast_nullable_to_non_nullable
as double,thermalConductivity: null == thermalConductivity ? _self.thermalConductivity : thermalConductivity // ignore: cast_nullable_to_non_nullable
as double,roughness: null == roughness ? _self.roughness : roughness // ignore: cast_nullable_to_non_nullable
as double,maxOperatingTempC: null == maxOperatingTempC ? _self.maxOperatingTempC : maxOperatingTempC // ignore: cast_nullable_to_non_nullable
as double,maxOperatingPressure: null == maxOperatingPressure ? _self.maxOperatingPressure : maxOperatingPressure // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TubeType].
extension TubeTypePatterns on TubeType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TubeType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TubeType() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TubeType value)  $default,){
final _that = this;
switch (_that) {
case _TubeType():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TubeType value)?  $default,){
final _that = this;
switch (_that) {
case _TubeType() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  TubeMaterial material,  double outerDiameterMm,  double innerDiameterMm,  double wallThicknessMm,  double thermalConductivity,  double roughness,  double maxOperatingTempC,  double maxOperatingPressure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TubeType() when $default != null:
return $default(_that.id,_that.name,_that.material,_that.outerDiameterMm,_that.innerDiameterMm,_that.wallThicknessMm,_that.thermalConductivity,_that.roughness,_that.maxOperatingTempC,_that.maxOperatingPressure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  TubeMaterial material,  double outerDiameterMm,  double innerDiameterMm,  double wallThicknessMm,  double thermalConductivity,  double roughness,  double maxOperatingTempC,  double maxOperatingPressure)  $default,) {final _that = this;
switch (_that) {
case _TubeType():
return $default(_that.id,_that.name,_that.material,_that.outerDiameterMm,_that.innerDiameterMm,_that.wallThicknessMm,_that.thermalConductivity,_that.roughness,_that.maxOperatingTempC,_that.maxOperatingPressure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  TubeMaterial material,  double outerDiameterMm,  double innerDiameterMm,  double wallThicknessMm,  double thermalConductivity,  double roughness,  double maxOperatingTempC,  double maxOperatingPressure)?  $default,) {final _that = this;
switch (_that) {
case _TubeType() when $default != null:
return $default(_that.id,_that.name,_that.material,_that.outerDiameterMm,_that.innerDiameterMm,_that.wallThicknessMm,_that.thermalConductivity,_that.roughness,_that.maxOperatingTempC,_that.maxOperatingPressure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TubeType implements TubeType {
  const _TubeType({required this.id, required this.name, required this.material, this.outerDiameterMm = 16.0, this.innerDiameterMm = 13.0, this.wallThicknessMm = 1.5, this.thermalConductivity = 0.35, this.roughness = 0.007, this.maxOperatingTempC = 60.0, this.maxOperatingPressure = 6.0});
  factory _TubeType.fromJson(Map<String, dynamic> json) => _$TubeTypeFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// Display name (1–100 chars).
@override final  String name;
/// Pipe material.
@override final  TubeMaterial material;
/// Outer diameter in millimetres. Range: 8.0–32.0.
@override@JsonKey() final  double outerDiameterMm;
/// Inner (bore) diameter in millimetres. Must be < [outerDiameterMm].
@override@JsonKey() final  double innerDiameterMm;
/// Wall thickness in millimetres (may be derived or explicitly set).
@override@JsonKey() final  double wallThicknessMm;
/// Thermal conductivity of the pipe wall in W/(m·K).
@override@JsonKey() final  double thermalConductivity;
/// Absolute roughness of the bore surface in mm. Range: 0.001–0.1.
@override@JsonKey() final  double roughness;
/// Maximum allowable fluid temperature in °C.
@override@JsonKey() final  double maxOperatingTempC;
/// Maximum allowable operating pressure in bar.
@override@JsonKey() final  double maxOperatingPressure;

/// Create a copy of TubeType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TubeTypeCopyWith<_TubeType> get copyWith => __$TubeTypeCopyWithImpl<_TubeType>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TubeTypeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TubeType&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.material, material) || other.material == material)&&(identical(other.outerDiameterMm, outerDiameterMm) || other.outerDiameterMm == outerDiameterMm)&&(identical(other.innerDiameterMm, innerDiameterMm) || other.innerDiameterMm == innerDiameterMm)&&(identical(other.wallThicknessMm, wallThicknessMm) || other.wallThicknessMm == wallThicknessMm)&&(identical(other.thermalConductivity, thermalConductivity) || other.thermalConductivity == thermalConductivity)&&(identical(other.roughness, roughness) || other.roughness == roughness)&&(identical(other.maxOperatingTempC, maxOperatingTempC) || other.maxOperatingTempC == maxOperatingTempC)&&(identical(other.maxOperatingPressure, maxOperatingPressure) || other.maxOperatingPressure == maxOperatingPressure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,material,outerDiameterMm,innerDiameterMm,wallThicknessMm,thermalConductivity,roughness,maxOperatingTempC,maxOperatingPressure);

@override
String toString() {
  return 'TubeType(id: $id, name: $name, material: $material, outerDiameterMm: $outerDiameterMm, innerDiameterMm: $innerDiameterMm, wallThicknessMm: $wallThicknessMm, thermalConductivity: $thermalConductivity, roughness: $roughness, maxOperatingTempC: $maxOperatingTempC, maxOperatingPressure: $maxOperatingPressure)';
}


}

/// @nodoc
abstract mixin class _$TubeTypeCopyWith<$Res> implements $TubeTypeCopyWith<$Res> {
  factory _$TubeTypeCopyWith(_TubeType value, $Res Function(_TubeType) _then) = __$TubeTypeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, TubeMaterial material, double outerDiameterMm, double innerDiameterMm, double wallThicknessMm, double thermalConductivity, double roughness, double maxOperatingTempC, double maxOperatingPressure
});




}
/// @nodoc
class __$TubeTypeCopyWithImpl<$Res>
    implements _$TubeTypeCopyWith<$Res> {
  __$TubeTypeCopyWithImpl(this._self, this._then);

  final _TubeType _self;
  final $Res Function(_TubeType) _then;

/// Create a copy of TubeType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? material = null,Object? outerDiameterMm = null,Object? innerDiameterMm = null,Object? wallThicknessMm = null,Object? thermalConductivity = null,Object? roughness = null,Object? maxOperatingTempC = null,Object? maxOperatingPressure = null,}) {
  return _then(_TubeType(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,material: null == material ? _self.material : material // ignore: cast_nullable_to_non_nullable
as TubeMaterial,outerDiameterMm: null == outerDiameterMm ? _self.outerDiameterMm : outerDiameterMm // ignore: cast_nullable_to_non_nullable
as double,innerDiameterMm: null == innerDiameterMm ? _self.innerDiameterMm : innerDiameterMm // ignore: cast_nullable_to_non_nullable
as double,wallThicknessMm: null == wallThicknessMm ? _self.wallThicknessMm : wallThicknessMm // ignore: cast_nullable_to_non_nullable
as double,thermalConductivity: null == thermalConductivity ? _self.thermalConductivity : thermalConductivity // ignore: cast_nullable_to_non_nullable
as double,roughness: null == roughness ? _self.roughness : roughness // ignore: cast_nullable_to_non_nullable
as double,maxOperatingTempC: null == maxOperatingTempC ? _self.maxOperatingTempC : maxOperatingTempC // ignore: cast_nullable_to_non_nullable
as double,maxOperatingPressure: null == maxOperatingPressure ? _self.maxOperatingPressure : maxOperatingPressure // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
