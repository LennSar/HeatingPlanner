// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wall_construction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WallConstruction {

/// UUID v4 primary key.
 String get id;/// Canonical English descriptive name (1–200 chars).
 String get name;/// Optional German display name. Falls back to [name] when absent.
 String? get nameDe;/// Interior surface resistance in m²·K/W (default per ISO 6946).
 double get rsi;/// Exterior surface resistance in m²·K/W (default per ISO 6946).
 double get rse;/// Whether this construction is a saved user preset.
///
/// Presets are stored in the same table and shown in the
/// "Load preset" picker inside the construction editor.
/// Loading a preset always deep-copies all layers so edits
/// never mutate the saved preset.
 bool get isPreset;
/// Create a copy of WallConstruction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallConstructionCopyWith<WallConstruction> get copyWith => _$WallConstructionCopyWithImpl<WallConstruction>(this as WallConstruction, _$identity);

  /// Serializes this WallConstruction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallConstruction&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameDe, nameDe) || other.nameDe == nameDe)&&(identical(other.rsi, rsi) || other.rsi == rsi)&&(identical(other.rse, rse) || other.rse == rse)&&(identical(other.isPreset, isPreset) || other.isPreset == isPreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameDe,rsi,rse,isPreset);

@override
String toString() {
  return 'WallConstruction(id: $id, name: $name, nameDe: $nameDe, rsi: $rsi, rse: $rse, isPreset: $isPreset)';
}


}

/// @nodoc
abstract mixin class $WallConstructionCopyWith<$Res>  {
  factory $WallConstructionCopyWith(WallConstruction value, $Res Function(WallConstruction) _then) = _$WallConstructionCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? nameDe, double rsi, double rse, bool isPreset
});




}
/// @nodoc
class _$WallConstructionCopyWithImpl<$Res>
    implements $WallConstructionCopyWith<$Res> {
  _$WallConstructionCopyWithImpl(this._self, this._then);

  final WallConstruction _self;
  final $Res Function(WallConstruction) _then;

/// Create a copy of WallConstruction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nameDe = freezed,Object? rsi = null,Object? rse = null,Object? isPreset = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameDe: freezed == nameDe ? _self.nameDe : nameDe // ignore: cast_nullable_to_non_nullable
as String?,rsi: null == rsi ? _self.rsi : rsi // ignore: cast_nullable_to_non_nullable
as double,rse: null == rse ? _self.rse : rse // ignore: cast_nullable_to_non_nullable
as double,isPreset: null == isPreset ? _self.isPreset : isPreset // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WallConstruction].
extension WallConstructionPatterns on WallConstruction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallConstruction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallConstruction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallConstruction value)  $default,){
final _that = this;
switch (_that) {
case _WallConstruction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallConstruction value)?  $default,){
final _that = this;
switch (_that) {
case _WallConstruction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? nameDe,  double rsi,  double rse,  bool isPreset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallConstruction() when $default != null:
return $default(_that.id,_that.name,_that.nameDe,_that.rsi,_that.rse,_that.isPreset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? nameDe,  double rsi,  double rse,  bool isPreset)  $default,) {final _that = this;
switch (_that) {
case _WallConstruction():
return $default(_that.id,_that.name,_that.nameDe,_that.rsi,_that.rse,_that.isPreset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? nameDe,  double rsi,  double rse,  bool isPreset)?  $default,) {final _that = this;
switch (_that) {
case _WallConstruction() when $default != null:
return $default(_that.id,_that.name,_that.nameDe,_that.rsi,_that.rse,_that.isPreset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallConstruction implements WallConstruction {
  const _WallConstruction({required this.id, required this.name, this.nameDe, this.rsi = 0.13, this.rse = 0.04, this.isPreset = false});
  factory _WallConstruction.fromJson(Map<String, dynamic> json) => _$WallConstructionFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// Canonical English descriptive name (1–200 chars).
@override final  String name;
/// Optional German display name. Falls back to [name] when absent.
@override final  String? nameDe;
/// Interior surface resistance in m²·K/W (default per ISO 6946).
@override@JsonKey() final  double rsi;
/// Exterior surface resistance in m²·K/W (default per ISO 6946).
@override@JsonKey() final  double rse;
/// Whether this construction is a saved user preset.
///
/// Presets are stored in the same table and shown in the
/// "Load preset" picker inside the construction editor.
/// Loading a preset always deep-copies all layers so edits
/// never mutate the saved preset.
@override@JsonKey() final  bool isPreset;

/// Create a copy of WallConstruction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallConstructionCopyWith<_WallConstruction> get copyWith => __$WallConstructionCopyWithImpl<_WallConstruction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallConstructionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallConstruction&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameDe, nameDe) || other.nameDe == nameDe)&&(identical(other.rsi, rsi) || other.rsi == rsi)&&(identical(other.rse, rse) || other.rse == rse)&&(identical(other.isPreset, isPreset) || other.isPreset == isPreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameDe,rsi,rse,isPreset);

@override
String toString() {
  return 'WallConstruction(id: $id, name: $name, nameDe: $nameDe, rsi: $rsi, rse: $rse, isPreset: $isPreset)';
}


}

/// @nodoc
abstract mixin class _$WallConstructionCopyWith<$Res> implements $WallConstructionCopyWith<$Res> {
  factory _$WallConstructionCopyWith(_WallConstruction value, $Res Function(_WallConstruction) _then) = __$WallConstructionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? nameDe, double rsi, double rse, bool isPreset
});




}
/// @nodoc
class __$WallConstructionCopyWithImpl<$Res>
    implements _$WallConstructionCopyWith<$Res> {
  __$WallConstructionCopyWithImpl(this._self, this._then);

  final _WallConstruction _self;
  final $Res Function(_WallConstruction) _then;

/// Create a copy of WallConstruction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nameDe = freezed,Object? rsi = null,Object? rse = null,Object? isPreset = null,}) {
  return _then(_WallConstruction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameDe: freezed == nameDe ? _self.nameDe : nameDe // ignore: cast_nullable_to_non_nullable
as String?,rsi: null == rsi ? _self.rsi : rsi // ignore: cast_nullable_to_non_nullable
as double,rse: null == rse ? _self.rse : rse // ignore: cast_nullable_to_non_nullable
as double,isPreset: null == isPreset ? _self.isPreset : isPreset // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
