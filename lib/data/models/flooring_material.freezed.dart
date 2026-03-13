// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flooring_material.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FlooringMaterial {

/// UUID v4 primary key.
 String get id;/// Display name (1–200 chars).
 String get name;/// Total thermal resistance of the covering in m²·K/W.
 double get thermalResistance;/// Which zone surface this material is applicable to.
 SurfaceType get surfaceType;
/// Create a copy of FlooringMaterial
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlooringMaterialCopyWith<FlooringMaterial> get copyWith => _$FlooringMaterialCopyWithImpl<FlooringMaterial>(this as FlooringMaterial, _$identity);

  /// Serializes this FlooringMaterial to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlooringMaterial&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.thermalResistance, thermalResistance) || other.thermalResistance == thermalResistance)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,thermalResistance,surfaceType);

@override
String toString() {
  return 'FlooringMaterial(id: $id, name: $name, thermalResistance: $thermalResistance, surfaceType: $surfaceType)';
}


}

/// @nodoc
abstract mixin class $FlooringMaterialCopyWith<$Res>  {
  factory $FlooringMaterialCopyWith(FlooringMaterial value, $Res Function(FlooringMaterial) _then) = _$FlooringMaterialCopyWithImpl;
@useResult
$Res call({
 String id, String name, double thermalResistance, SurfaceType surfaceType
});




}
/// @nodoc
class _$FlooringMaterialCopyWithImpl<$Res>
    implements $FlooringMaterialCopyWith<$Res> {
  _$FlooringMaterialCopyWithImpl(this._self, this._then);

  final FlooringMaterial _self;
  final $Res Function(FlooringMaterial) _then;

/// Create a copy of FlooringMaterial
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? thermalResistance = null,Object? surfaceType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,thermalResistance: null == thermalResistance ? _self.thermalResistance : thermalResistance // ignore: cast_nullable_to_non_nullable
as double,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as SurfaceType,
  ));
}

}


/// Adds pattern-matching-related methods to [FlooringMaterial].
extension FlooringMaterialPatterns on FlooringMaterial {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlooringMaterial value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlooringMaterial() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlooringMaterial value)  $default,){
final _that = this;
switch (_that) {
case _FlooringMaterial():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlooringMaterial value)?  $default,){
final _that = this;
switch (_that) {
case _FlooringMaterial() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double thermalResistance,  SurfaceType surfaceType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlooringMaterial() when $default != null:
return $default(_that.id,_that.name,_that.thermalResistance,_that.surfaceType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double thermalResistance,  SurfaceType surfaceType)  $default,) {final _that = this;
switch (_that) {
case _FlooringMaterial():
return $default(_that.id,_that.name,_that.thermalResistance,_that.surfaceType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double thermalResistance,  SurfaceType surfaceType)?  $default,) {final _that = this;
switch (_that) {
case _FlooringMaterial() when $default != null:
return $default(_that.id,_that.name,_that.thermalResistance,_that.surfaceType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlooringMaterial implements FlooringMaterial {
  const _FlooringMaterial({required this.id, required this.name, required this.thermalResistance, this.surfaceType = SurfaceType.floor});
  factory _FlooringMaterial.fromJson(Map<String, dynamic> json) => _$FlooringMaterialFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// Display name (1–200 chars).
@override final  String name;
/// Total thermal resistance of the covering in m²·K/W.
@override final  double thermalResistance;
/// Which zone surface this material is applicable to.
@override@JsonKey() final  SurfaceType surfaceType;

/// Create a copy of FlooringMaterial
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlooringMaterialCopyWith<_FlooringMaterial> get copyWith => __$FlooringMaterialCopyWithImpl<_FlooringMaterial>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlooringMaterialToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlooringMaterial&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.thermalResistance, thermalResistance) || other.thermalResistance == thermalResistance)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,thermalResistance,surfaceType);

@override
String toString() {
  return 'FlooringMaterial(id: $id, name: $name, thermalResistance: $thermalResistance, surfaceType: $surfaceType)';
}


}

/// @nodoc
abstract mixin class _$FlooringMaterialCopyWith<$Res> implements $FlooringMaterialCopyWith<$Res> {
  factory _$FlooringMaterialCopyWith(_FlooringMaterial value, $Res Function(_FlooringMaterial) _then) = __$FlooringMaterialCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double thermalResistance, SurfaceType surfaceType
});




}
/// @nodoc
class __$FlooringMaterialCopyWithImpl<$Res>
    implements _$FlooringMaterialCopyWith<$Res> {
  __$FlooringMaterialCopyWithImpl(this._self, this._then);

  final _FlooringMaterial _self;
  final $Res Function(_FlooringMaterial) _then;

/// Create a copy of FlooringMaterial
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? thermalResistance = null,Object? surfaceType = null,}) {
  return _then(_FlooringMaterial(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,thermalResistance: null == thermalResistance ? _self.thermalResistance : thermalResistance // ignore: cast_nullable_to_non_nullable
as double,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as SurfaceType,
  ));
}


}

// dart format on
