// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'heating_circuit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HeatingCircuit {

/// UUID v4 primary key.
 String get id;/// UUID of the parent [Distributor].
 String get distributorId;/// UUID of the [HeatingZone] served by this circuit.
 String get heatingZoneId;/// Continuous polyline from distributor to zone entry, in mm coords.
 List<Point2D> get supplyRoutePath;/// Continuous polyline from zone exit back to distributor, in mm coords.
 List<Point2D> get returnRoutePath;/// Total pipe length in metres (calculated).
 double get tubeLengthM;/// Design flow rate in kg/h (calculated).
 double get flowRateKgH;/// Pressure drop across this circuit in Pa (calculated).
 double get pressureLossPa;/// Valve pre-setting for hydraulic balancing (calculated).
 double get valveSetting;
/// Create a copy of HeatingCircuit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeatingCircuitCopyWith<HeatingCircuit> get copyWith => _$HeatingCircuitCopyWithImpl<HeatingCircuit>(this as HeatingCircuit, _$identity);

  /// Serializes this HeatingCircuit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeatingCircuit&&(identical(other.id, id) || other.id == id)&&(identical(other.distributorId, distributorId) || other.distributorId == distributorId)&&(identical(other.heatingZoneId, heatingZoneId) || other.heatingZoneId == heatingZoneId)&&const DeepCollectionEquality().equals(other.supplyRoutePath, supplyRoutePath)&&const DeepCollectionEquality().equals(other.returnRoutePath, returnRoutePath)&&(identical(other.tubeLengthM, tubeLengthM) || other.tubeLengthM == tubeLengthM)&&(identical(other.flowRateKgH, flowRateKgH) || other.flowRateKgH == flowRateKgH)&&(identical(other.pressureLossPa, pressureLossPa) || other.pressureLossPa == pressureLossPa)&&(identical(other.valveSetting, valveSetting) || other.valveSetting == valveSetting));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,distributorId,heatingZoneId,const DeepCollectionEquality().hash(supplyRoutePath),const DeepCollectionEquality().hash(returnRoutePath),tubeLengthM,flowRateKgH,pressureLossPa,valveSetting);

@override
String toString() {
  return 'HeatingCircuit(id: $id, distributorId: $distributorId, heatingZoneId: $heatingZoneId, supplyRoutePath: $supplyRoutePath, returnRoutePath: $returnRoutePath, tubeLengthM: $tubeLengthM, flowRateKgH: $flowRateKgH, pressureLossPa: $pressureLossPa, valveSetting: $valveSetting)';
}


}

/// @nodoc
abstract mixin class $HeatingCircuitCopyWith<$Res>  {
  factory $HeatingCircuitCopyWith(HeatingCircuit value, $Res Function(HeatingCircuit) _then) = _$HeatingCircuitCopyWithImpl;
@useResult
$Res call({
 String id, String distributorId, String heatingZoneId, List<Point2D> supplyRoutePath, List<Point2D> returnRoutePath, double tubeLengthM, double flowRateKgH, double pressureLossPa, double valveSetting
});




}
/// @nodoc
class _$HeatingCircuitCopyWithImpl<$Res>
    implements $HeatingCircuitCopyWith<$Res> {
  _$HeatingCircuitCopyWithImpl(this._self, this._then);

  final HeatingCircuit _self;
  final $Res Function(HeatingCircuit) _then;

/// Create a copy of HeatingCircuit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? distributorId = null,Object? heatingZoneId = null,Object? supplyRoutePath = null,Object? returnRoutePath = null,Object? tubeLengthM = null,Object? flowRateKgH = null,Object? pressureLossPa = null,Object? valveSetting = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,distributorId: null == distributorId ? _self.distributorId : distributorId // ignore: cast_nullable_to_non_nullable
as String,heatingZoneId: null == heatingZoneId ? _self.heatingZoneId : heatingZoneId // ignore: cast_nullable_to_non_nullable
as String,supplyRoutePath: null == supplyRoutePath ? _self.supplyRoutePath : supplyRoutePath // ignore: cast_nullable_to_non_nullable
as List<Point2D>,returnRoutePath: null == returnRoutePath ? _self.returnRoutePath : returnRoutePath // ignore: cast_nullable_to_non_nullable
as List<Point2D>,tubeLengthM: null == tubeLengthM ? _self.tubeLengthM : tubeLengthM // ignore: cast_nullable_to_non_nullable
as double,flowRateKgH: null == flowRateKgH ? _self.flowRateKgH : flowRateKgH // ignore: cast_nullable_to_non_nullable
as double,pressureLossPa: null == pressureLossPa ? _self.pressureLossPa : pressureLossPa // ignore: cast_nullable_to_non_nullable
as double,valveSetting: null == valveSetting ? _self.valveSetting : valveSetting // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [HeatingCircuit].
extension HeatingCircuitPatterns on HeatingCircuit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeatingCircuit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeatingCircuit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeatingCircuit value)  $default,){
final _that = this;
switch (_that) {
case _HeatingCircuit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeatingCircuit value)?  $default,){
final _that = this;
switch (_that) {
case _HeatingCircuit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String distributorId,  String heatingZoneId,  List<Point2D> supplyRoutePath,  List<Point2D> returnRoutePath,  double tubeLengthM,  double flowRateKgH,  double pressureLossPa,  double valveSetting)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeatingCircuit() when $default != null:
return $default(_that.id,_that.distributorId,_that.heatingZoneId,_that.supplyRoutePath,_that.returnRoutePath,_that.tubeLengthM,_that.flowRateKgH,_that.pressureLossPa,_that.valveSetting);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String distributorId,  String heatingZoneId,  List<Point2D> supplyRoutePath,  List<Point2D> returnRoutePath,  double tubeLengthM,  double flowRateKgH,  double pressureLossPa,  double valveSetting)  $default,) {final _that = this;
switch (_that) {
case _HeatingCircuit():
return $default(_that.id,_that.distributorId,_that.heatingZoneId,_that.supplyRoutePath,_that.returnRoutePath,_that.tubeLengthM,_that.flowRateKgH,_that.pressureLossPa,_that.valveSetting);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String distributorId,  String heatingZoneId,  List<Point2D> supplyRoutePath,  List<Point2D> returnRoutePath,  double tubeLengthM,  double flowRateKgH,  double pressureLossPa,  double valveSetting)?  $default,) {final _that = this;
switch (_that) {
case _HeatingCircuit() when $default != null:
return $default(_that.id,_that.distributorId,_that.heatingZoneId,_that.supplyRoutePath,_that.returnRoutePath,_that.tubeLengthM,_that.flowRateKgH,_that.pressureLossPa,_that.valveSetting);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HeatingCircuit implements HeatingCircuit {
  const _HeatingCircuit({required this.id, required this.distributorId, required this.heatingZoneId, final  List<Point2D> supplyRoutePath = const [], final  List<Point2D> returnRoutePath = const [], this.tubeLengthM = 0.0, this.flowRateKgH = 0.0, this.pressureLossPa = 0.0, this.valveSetting = 0.0}): _supplyRoutePath = supplyRoutePath,_returnRoutePath = returnRoutePath;
  factory _HeatingCircuit.fromJson(Map<String, dynamic> json) => _$HeatingCircuitFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the parent [Distributor].
@override final  String distributorId;
/// UUID of the [HeatingZone] served by this circuit.
@override final  String heatingZoneId;
/// Continuous polyline from distributor to zone entry, in mm coords.
 final  List<Point2D> _supplyRoutePath;
/// Continuous polyline from distributor to zone entry, in mm coords.
@override@JsonKey() List<Point2D> get supplyRoutePath {
  if (_supplyRoutePath is EqualUnmodifiableListView) return _supplyRoutePath;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supplyRoutePath);
}

/// Continuous polyline from zone exit back to distributor, in mm coords.
 final  List<Point2D> _returnRoutePath;
/// Continuous polyline from zone exit back to distributor, in mm coords.
@override@JsonKey() List<Point2D> get returnRoutePath {
  if (_returnRoutePath is EqualUnmodifiableListView) return _returnRoutePath;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_returnRoutePath);
}

/// Total pipe length in metres (calculated).
@override@JsonKey() final  double tubeLengthM;
/// Design flow rate in kg/h (calculated).
@override@JsonKey() final  double flowRateKgH;
/// Pressure drop across this circuit in Pa (calculated).
@override@JsonKey() final  double pressureLossPa;
/// Valve pre-setting for hydraulic balancing (calculated).
@override@JsonKey() final  double valveSetting;

/// Create a copy of HeatingCircuit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeatingCircuitCopyWith<_HeatingCircuit> get copyWith => __$HeatingCircuitCopyWithImpl<_HeatingCircuit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeatingCircuitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeatingCircuit&&(identical(other.id, id) || other.id == id)&&(identical(other.distributorId, distributorId) || other.distributorId == distributorId)&&(identical(other.heatingZoneId, heatingZoneId) || other.heatingZoneId == heatingZoneId)&&const DeepCollectionEquality().equals(other._supplyRoutePath, _supplyRoutePath)&&const DeepCollectionEquality().equals(other._returnRoutePath, _returnRoutePath)&&(identical(other.tubeLengthM, tubeLengthM) || other.tubeLengthM == tubeLengthM)&&(identical(other.flowRateKgH, flowRateKgH) || other.flowRateKgH == flowRateKgH)&&(identical(other.pressureLossPa, pressureLossPa) || other.pressureLossPa == pressureLossPa)&&(identical(other.valveSetting, valveSetting) || other.valveSetting == valveSetting));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,distributorId,heatingZoneId,const DeepCollectionEquality().hash(_supplyRoutePath),const DeepCollectionEquality().hash(_returnRoutePath),tubeLengthM,flowRateKgH,pressureLossPa,valveSetting);

@override
String toString() {
  return 'HeatingCircuit(id: $id, distributorId: $distributorId, heatingZoneId: $heatingZoneId, supplyRoutePath: $supplyRoutePath, returnRoutePath: $returnRoutePath, tubeLengthM: $tubeLengthM, flowRateKgH: $flowRateKgH, pressureLossPa: $pressureLossPa, valveSetting: $valveSetting)';
}


}

/// @nodoc
abstract mixin class _$HeatingCircuitCopyWith<$Res> implements $HeatingCircuitCopyWith<$Res> {
  factory _$HeatingCircuitCopyWith(_HeatingCircuit value, $Res Function(_HeatingCircuit) _then) = __$HeatingCircuitCopyWithImpl;
@override @useResult
$Res call({
 String id, String distributorId, String heatingZoneId, List<Point2D> supplyRoutePath, List<Point2D> returnRoutePath, double tubeLengthM, double flowRateKgH, double pressureLossPa, double valveSetting
});




}
/// @nodoc
class __$HeatingCircuitCopyWithImpl<$Res>
    implements _$HeatingCircuitCopyWith<$Res> {
  __$HeatingCircuitCopyWithImpl(this._self, this._then);

  final _HeatingCircuit _self;
  final $Res Function(_HeatingCircuit) _then;

/// Create a copy of HeatingCircuit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? distributorId = null,Object? heatingZoneId = null,Object? supplyRoutePath = null,Object? returnRoutePath = null,Object? tubeLengthM = null,Object? flowRateKgH = null,Object? pressureLossPa = null,Object? valveSetting = null,}) {
  return _then(_HeatingCircuit(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,distributorId: null == distributorId ? _self.distributorId : distributorId // ignore: cast_nullable_to_non_nullable
as String,heatingZoneId: null == heatingZoneId ? _self.heatingZoneId : heatingZoneId // ignore: cast_nullable_to_non_nullable
as String,supplyRoutePath: null == supplyRoutePath ? _self._supplyRoutePath : supplyRoutePath // ignore: cast_nullable_to_non_nullable
as List<Point2D>,returnRoutePath: null == returnRoutePath ? _self._returnRoutePath : returnRoutePath // ignore: cast_nullable_to_non_nullable
as List<Point2D>,tubeLengthM: null == tubeLengthM ? _self.tubeLengthM : tubeLengthM // ignore: cast_nullable_to_non_nullable
as double,flowRateKgH: null == flowRateKgH ? _self.flowRateKgH : flowRateKgH // ignore: cast_nullable_to_non_nullable
as double,pressureLossPa: null == pressureLossPa ? _self.pressureLossPa : pressureLossPa // ignore: cast_nullable_to_non_nullable
as double,valveSetting: null == valveSetting ? _self.valveSetting : valveSetting // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
