// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'distributor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Distributor {

/// UUID v4 primary key.
 String get id;/// UUID of the [Floor] this distributor is placed on.
 String get floorId;/// Position of the distributor on the floor plan in millimetres.
 Point2D get position;/// Supply water temperature in °C. Range: 20–55.
 double get supplyTempC;/// Return water temperature in °C. Must be < [supplyTempC].
 double get returnTempC;/// Available pump head pressure in Pa. Must be > 0.
 double get pumpHeadPa;
/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DistributorCopyWith<Distributor> get copyWith => _$DistributorCopyWithImpl<Distributor>(this as Distributor, _$identity);

  /// Serializes this Distributor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Distributor&&(identical(other.id, id) || other.id == id)&&(identical(other.floorId, floorId) || other.floorId == floorId)&&(identical(other.position, position) || other.position == position)&&(identical(other.supplyTempC, supplyTempC) || other.supplyTempC == supplyTempC)&&(identical(other.returnTempC, returnTempC) || other.returnTempC == returnTempC)&&(identical(other.pumpHeadPa, pumpHeadPa) || other.pumpHeadPa == pumpHeadPa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,floorId,position,supplyTempC,returnTempC,pumpHeadPa);

@override
String toString() {
  return 'Distributor(id: $id, floorId: $floorId, position: $position, supplyTempC: $supplyTempC, returnTempC: $returnTempC, pumpHeadPa: $pumpHeadPa)';
}


}

/// @nodoc
abstract mixin class $DistributorCopyWith<$Res>  {
  factory $DistributorCopyWith(Distributor value, $Res Function(Distributor) _then) = _$DistributorCopyWithImpl;
@useResult
$Res call({
 String id, String floorId, Point2D position, double supplyTempC, double returnTempC, double pumpHeadPa
});


$Point2DCopyWith<$Res> get position;

}
/// @nodoc
class _$DistributorCopyWithImpl<$Res>
    implements $DistributorCopyWith<$Res> {
  _$DistributorCopyWithImpl(this._self, this._then);

  final Distributor _self;
  final $Res Function(Distributor) _then;

/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? floorId = null,Object? position = null,Object? supplyTempC = null,Object? returnTempC = null,Object? pumpHeadPa = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,floorId: null == floorId ? _self.floorId : floorId // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Point2D,supplyTempC: null == supplyTempC ? _self.supplyTempC : supplyTempC // ignore: cast_nullable_to_non_nullable
as double,returnTempC: null == returnTempC ? _self.returnTempC : returnTempC // ignore: cast_nullable_to_non_nullable
as double,pumpHeadPa: null == pumpHeadPa ? _self.pumpHeadPa : pumpHeadPa // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get position {
  
  return $Point2DCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}


/// Adds pattern-matching-related methods to [Distributor].
extension DistributorPatterns on Distributor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Distributor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Distributor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Distributor value)  $default,){
final _that = this;
switch (_that) {
case _Distributor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Distributor value)?  $default,){
final _that = this;
switch (_that) {
case _Distributor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String floorId,  Point2D position,  double supplyTempC,  double returnTempC,  double pumpHeadPa)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Distributor() when $default != null:
return $default(_that.id,_that.floorId,_that.position,_that.supplyTempC,_that.returnTempC,_that.pumpHeadPa);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String floorId,  Point2D position,  double supplyTempC,  double returnTempC,  double pumpHeadPa)  $default,) {final _that = this;
switch (_that) {
case _Distributor():
return $default(_that.id,_that.floorId,_that.position,_that.supplyTempC,_that.returnTempC,_that.pumpHeadPa);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String floorId,  Point2D position,  double supplyTempC,  double returnTempC,  double pumpHeadPa)?  $default,) {final _that = this;
switch (_that) {
case _Distributor() when $default != null:
return $default(_that.id,_that.floorId,_that.position,_that.supplyTempC,_that.returnTempC,_that.pumpHeadPa);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Distributor implements Distributor {
  const _Distributor({required this.id, required this.floorId, required this.position, this.supplyTempC = 35.0, this.returnTempC = 28.0, this.pumpHeadPa = 25000.0});
  factory _Distributor.fromJson(Map<String, dynamic> json) => _$DistributorFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the [Floor] this distributor is placed on.
@override final  String floorId;
/// Position of the distributor on the floor plan in millimetres.
@override final  Point2D position;
/// Supply water temperature in °C. Range: 20–55.
@override@JsonKey() final  double supplyTempC;
/// Return water temperature in °C. Must be < [supplyTempC].
@override@JsonKey() final  double returnTempC;
/// Available pump head pressure in Pa. Must be > 0.
@override@JsonKey() final  double pumpHeadPa;

/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DistributorCopyWith<_Distributor> get copyWith => __$DistributorCopyWithImpl<_Distributor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DistributorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Distributor&&(identical(other.id, id) || other.id == id)&&(identical(other.floorId, floorId) || other.floorId == floorId)&&(identical(other.position, position) || other.position == position)&&(identical(other.supplyTempC, supplyTempC) || other.supplyTempC == supplyTempC)&&(identical(other.returnTempC, returnTempC) || other.returnTempC == returnTempC)&&(identical(other.pumpHeadPa, pumpHeadPa) || other.pumpHeadPa == pumpHeadPa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,floorId,position,supplyTempC,returnTempC,pumpHeadPa);

@override
String toString() {
  return 'Distributor(id: $id, floorId: $floorId, position: $position, supplyTempC: $supplyTempC, returnTempC: $returnTempC, pumpHeadPa: $pumpHeadPa)';
}


}

/// @nodoc
abstract mixin class _$DistributorCopyWith<$Res> implements $DistributorCopyWith<$Res> {
  factory _$DistributorCopyWith(_Distributor value, $Res Function(_Distributor) _then) = __$DistributorCopyWithImpl;
@override @useResult
$Res call({
 String id, String floorId, Point2D position, double supplyTempC, double returnTempC, double pumpHeadPa
});


@override $Point2DCopyWith<$Res> get position;

}
/// @nodoc
class __$DistributorCopyWithImpl<$Res>
    implements _$DistributorCopyWith<$Res> {
  __$DistributorCopyWithImpl(this._self, this._then);

  final _Distributor _self;
  final $Res Function(_Distributor) _then;

/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? floorId = null,Object? position = null,Object? supplyTempC = null,Object? returnTempC = null,Object? pumpHeadPa = null,}) {
  return _then(_Distributor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,floorId: null == floorId ? _self.floorId : floorId // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Point2D,supplyTempC: null == supplyTempC ? _self.supplyTempC : supplyTempC // ignore: cast_nullable_to_non_nullable
as double,returnTempC: null == returnTempC ? _self.returnTempC : returnTempC // ignore: cast_nullable_to_non_nullable
as double,pumpHeadPa: null == pumpHeadPa ? _self.pumpHeadPa : pumpHeadPa // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of Distributor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get position {
  
  return $Point2DCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}

// dart format on
