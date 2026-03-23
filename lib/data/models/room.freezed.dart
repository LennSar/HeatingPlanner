// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Room {

/// UUID v4 primary key.
 String get id;/// UUID of the parent [Floor].
 String get floorId;/// Display name (1–100 chars).
 String get name;/// Target indoor temperature in °C. Range: 15.0–30.0.
 double get targetTempC;/// Ventilation air-change rate in h⁻¹. Range: 0.1–5.0.
 double get airChangeRate;/// Room boundary polygon. Must be closed (last vertex = first vertex)
/// and contain at least 3 distinct vertices.
 List<Point2D> get polygon;/// UUID of the [WallConstruction] used for floor/slab.
/// Null = not assigned.
 String? get floorConstructionId;/// UUID of the [WallConstruction] used for ceiling/roof.
/// Null = not assigned.
 String? get ceilingConstructionId;/// Boundary condition below the floor slab.
 BoundaryCondition get floorBoundary;/// Boundary condition above the ceiling slab.
 BoundaryCondition get ceilingBoundary;/// Per-room adjacent temperature (°C) for the floor boundary.
///
/// Used when [floorBoundary] is [BoundaryCondition.unheatedSpace] or
/// [BoundaryCondition.interior]. Null means the project-level default
/// is used (unheatedSpaceTempC for unheated, defaultIndoorTempC for
/// interior).
 double? get floorAdjacentTempC;/// Per-room adjacent temperature (°C) for the ceiling boundary.
///
/// Used when [ceilingBoundary] is [BoundaryCondition.unheatedSpace] or
/// [BoundaryCondition.interior]. Null means the project-level default
/// is used (unheatedSpaceTempC for unheated, defaultIndoorTempC for
/// interior).
 double? get ceilingAdjacentTempC;
/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomCopyWith<Room> get copyWith => _$RoomCopyWithImpl<Room>(this as Room, _$identity);

  /// Serializes this Room to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Room&&(identical(other.id, id) || other.id == id)&&(identical(other.floorId, floorId) || other.floorId == floorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.targetTempC, targetTempC) || other.targetTempC == targetTempC)&&(identical(other.airChangeRate, airChangeRate) || other.airChangeRate == airChangeRate)&&const DeepCollectionEquality().equals(other.polygon, polygon)&&(identical(other.floorConstructionId, floorConstructionId) || other.floorConstructionId == floorConstructionId)&&(identical(other.ceilingConstructionId, ceilingConstructionId) || other.ceilingConstructionId == ceilingConstructionId)&&(identical(other.floorBoundary, floorBoundary) || other.floorBoundary == floorBoundary)&&(identical(other.ceilingBoundary, ceilingBoundary) || other.ceilingBoundary == ceilingBoundary)&&(identical(other.floorAdjacentTempC, floorAdjacentTempC) || other.floorAdjacentTempC == floorAdjacentTempC)&&(identical(other.ceilingAdjacentTempC, ceilingAdjacentTempC) || other.ceilingAdjacentTempC == ceilingAdjacentTempC));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,floorId,name,targetTempC,airChangeRate,const DeepCollectionEquality().hash(polygon),floorConstructionId,ceilingConstructionId,floorBoundary,ceilingBoundary,floorAdjacentTempC,ceilingAdjacentTempC);

@override
String toString() {
  return 'Room(id: $id, floorId: $floorId, name: $name, targetTempC: $targetTempC, airChangeRate: $airChangeRate, polygon: $polygon, floorConstructionId: $floorConstructionId, ceilingConstructionId: $ceilingConstructionId, floorBoundary: $floorBoundary, ceilingBoundary: $ceilingBoundary, floorAdjacentTempC: $floorAdjacentTempC, ceilingAdjacentTempC: $ceilingAdjacentTempC)';
}


}

/// @nodoc
abstract mixin class $RoomCopyWith<$Res>  {
  factory $RoomCopyWith(Room value, $Res Function(Room) _then) = _$RoomCopyWithImpl;
@useResult
$Res call({
 String id, String floorId, String name, double targetTempC, double airChangeRate, List<Point2D> polygon, String? floorConstructionId, String? ceilingConstructionId, BoundaryCondition floorBoundary, BoundaryCondition ceilingBoundary, double? floorAdjacentTempC, double? ceilingAdjacentTempC
});




}
/// @nodoc
class _$RoomCopyWithImpl<$Res>
    implements $RoomCopyWith<$Res> {
  _$RoomCopyWithImpl(this._self, this._then);

  final Room _self;
  final $Res Function(Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? floorId = null,Object? name = null,Object? targetTempC = null,Object? airChangeRate = null,Object? polygon = null,Object? floorConstructionId = freezed,Object? ceilingConstructionId = freezed,Object? floorBoundary = null,Object? ceilingBoundary = null,Object? floorAdjacentTempC = freezed,Object? ceilingAdjacentTempC = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,floorId: null == floorId ? _self.floorId : floorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,targetTempC: null == targetTempC ? _self.targetTempC : targetTempC // ignore: cast_nullable_to_non_nullable
as double,airChangeRate: null == airChangeRate ? _self.airChangeRate : airChangeRate // ignore: cast_nullable_to_non_nullable
as double,polygon: null == polygon ? _self.polygon : polygon // ignore: cast_nullable_to_non_nullable
as List<Point2D>,floorConstructionId: freezed == floorConstructionId ? _self.floorConstructionId : floorConstructionId // ignore: cast_nullable_to_non_nullable
as String?,ceilingConstructionId: freezed == ceilingConstructionId ? _self.ceilingConstructionId : ceilingConstructionId // ignore: cast_nullable_to_non_nullable
as String?,floorBoundary: null == floorBoundary ? _self.floorBoundary : floorBoundary // ignore: cast_nullable_to_non_nullable
as BoundaryCondition,ceilingBoundary: null == ceilingBoundary ? _self.ceilingBoundary : ceilingBoundary // ignore: cast_nullable_to_non_nullable
as BoundaryCondition,floorAdjacentTempC: freezed == floorAdjacentTempC ? _self.floorAdjacentTempC : floorAdjacentTempC // ignore: cast_nullable_to_non_nullable
as double?,ceilingAdjacentTempC: freezed == ceilingAdjacentTempC ? _self.ceilingAdjacentTempC : ceilingAdjacentTempC // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Room].
extension RoomPatterns on Room {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Room value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Room value)  $default,){
final _that = this;
switch (_that) {
case _Room():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Room value)?  $default,){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String floorId,  String name,  double targetTempC,  double airChangeRate,  List<Point2D> polygon,  String? floorConstructionId,  String? ceilingConstructionId,  BoundaryCondition floorBoundary,  BoundaryCondition ceilingBoundary,  double? floorAdjacentTempC,  double? ceilingAdjacentTempC)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.floorId,_that.name,_that.targetTempC,_that.airChangeRate,_that.polygon,_that.floorConstructionId,_that.ceilingConstructionId,_that.floorBoundary,_that.ceilingBoundary,_that.floorAdjacentTempC,_that.ceilingAdjacentTempC);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String floorId,  String name,  double targetTempC,  double airChangeRate,  List<Point2D> polygon,  String? floorConstructionId,  String? ceilingConstructionId,  BoundaryCondition floorBoundary,  BoundaryCondition ceilingBoundary,  double? floorAdjacentTempC,  double? ceilingAdjacentTempC)  $default,) {final _that = this;
switch (_that) {
case _Room():
return $default(_that.id,_that.floorId,_that.name,_that.targetTempC,_that.airChangeRate,_that.polygon,_that.floorConstructionId,_that.ceilingConstructionId,_that.floorBoundary,_that.ceilingBoundary,_that.floorAdjacentTempC,_that.ceilingAdjacentTempC);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String floorId,  String name,  double targetTempC,  double airChangeRate,  List<Point2D> polygon,  String? floorConstructionId,  String? ceilingConstructionId,  BoundaryCondition floorBoundary,  BoundaryCondition ceilingBoundary,  double? floorAdjacentTempC,  double? ceilingAdjacentTempC)?  $default,) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.floorId,_that.name,_that.targetTempC,_that.airChangeRate,_that.polygon,_that.floorConstructionId,_that.ceilingConstructionId,_that.floorBoundary,_that.ceilingBoundary,_that.floorAdjacentTempC,_that.ceilingAdjacentTempC);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Room implements Room {
  const _Room({required this.id, required this.floorId, required this.name, this.targetTempC = 20.0, this.airChangeRate = 0.5, final  List<Point2D> polygon = const [], this.floorConstructionId, this.ceilingConstructionId, this.floorBoundary = BoundaryCondition.ground, this.ceilingBoundary = BoundaryCondition.exterior, this.floorAdjacentTempC, this.ceilingAdjacentTempC}): _polygon = polygon;
  factory _Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the parent [Floor].
@override final  String floorId;
/// Display name (1–100 chars).
@override final  String name;
/// Target indoor temperature in °C. Range: 15.0–30.0.
@override@JsonKey() final  double targetTempC;
/// Ventilation air-change rate in h⁻¹. Range: 0.1–5.0.
@override@JsonKey() final  double airChangeRate;
/// Room boundary polygon. Must be closed (last vertex = first vertex)
/// and contain at least 3 distinct vertices.
 final  List<Point2D> _polygon;
/// Room boundary polygon. Must be closed (last vertex = first vertex)
/// and contain at least 3 distinct vertices.
@override@JsonKey() List<Point2D> get polygon {
  if (_polygon is EqualUnmodifiableListView) return _polygon;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_polygon);
}

/// UUID of the [WallConstruction] used for floor/slab.
/// Null = not assigned.
@override final  String? floorConstructionId;
/// UUID of the [WallConstruction] used for ceiling/roof.
/// Null = not assigned.
@override final  String? ceilingConstructionId;
/// Boundary condition below the floor slab.
@override@JsonKey() final  BoundaryCondition floorBoundary;
/// Boundary condition above the ceiling slab.
@override@JsonKey() final  BoundaryCondition ceilingBoundary;
/// Per-room adjacent temperature (°C) for the floor boundary.
///
/// Used when [floorBoundary] is [BoundaryCondition.unheatedSpace] or
/// [BoundaryCondition.interior]. Null means the project-level default
/// is used (unheatedSpaceTempC for unheated, defaultIndoorTempC for
/// interior).
@override final  double? floorAdjacentTempC;
/// Per-room adjacent temperature (°C) for the ceiling boundary.
///
/// Used when [ceilingBoundary] is [BoundaryCondition.unheatedSpace] or
/// [BoundaryCondition.interior]. Null means the project-level default
/// is used (unheatedSpaceTempC for unheated, defaultIndoorTempC for
/// interior).
@override final  double? ceilingAdjacentTempC;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomCopyWith<_Room> get copyWith => __$RoomCopyWithImpl<_Room>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Room&&(identical(other.id, id) || other.id == id)&&(identical(other.floorId, floorId) || other.floorId == floorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.targetTempC, targetTempC) || other.targetTempC == targetTempC)&&(identical(other.airChangeRate, airChangeRate) || other.airChangeRate == airChangeRate)&&const DeepCollectionEquality().equals(other._polygon, _polygon)&&(identical(other.floorConstructionId, floorConstructionId) || other.floorConstructionId == floorConstructionId)&&(identical(other.ceilingConstructionId, ceilingConstructionId) || other.ceilingConstructionId == ceilingConstructionId)&&(identical(other.floorBoundary, floorBoundary) || other.floorBoundary == floorBoundary)&&(identical(other.ceilingBoundary, ceilingBoundary) || other.ceilingBoundary == ceilingBoundary)&&(identical(other.floorAdjacentTempC, floorAdjacentTempC) || other.floorAdjacentTempC == floorAdjacentTempC)&&(identical(other.ceilingAdjacentTempC, ceilingAdjacentTempC) || other.ceilingAdjacentTempC == ceilingAdjacentTempC));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,floorId,name,targetTempC,airChangeRate,const DeepCollectionEquality().hash(_polygon),floorConstructionId,ceilingConstructionId,floorBoundary,ceilingBoundary,floorAdjacentTempC,ceilingAdjacentTempC);

@override
String toString() {
  return 'Room(id: $id, floorId: $floorId, name: $name, targetTempC: $targetTempC, airChangeRate: $airChangeRate, polygon: $polygon, floorConstructionId: $floorConstructionId, ceilingConstructionId: $ceilingConstructionId, floorBoundary: $floorBoundary, ceilingBoundary: $ceilingBoundary, floorAdjacentTempC: $floorAdjacentTempC, ceilingAdjacentTempC: $ceilingAdjacentTempC)';
}


}

/// @nodoc
abstract mixin class _$RoomCopyWith<$Res> implements $RoomCopyWith<$Res> {
  factory _$RoomCopyWith(_Room value, $Res Function(_Room) _then) = __$RoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String floorId, String name, double targetTempC, double airChangeRate, List<Point2D> polygon, String? floorConstructionId, String? ceilingConstructionId, BoundaryCondition floorBoundary, BoundaryCondition ceilingBoundary, double? floorAdjacentTempC, double? ceilingAdjacentTempC
});




}
/// @nodoc
class __$RoomCopyWithImpl<$Res>
    implements _$RoomCopyWith<$Res> {
  __$RoomCopyWithImpl(this._self, this._then);

  final _Room _self;
  final $Res Function(_Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? floorId = null,Object? name = null,Object? targetTempC = null,Object? airChangeRate = null,Object? polygon = null,Object? floorConstructionId = freezed,Object? ceilingConstructionId = freezed,Object? floorBoundary = null,Object? ceilingBoundary = null,Object? floorAdjacentTempC = freezed,Object? ceilingAdjacentTempC = freezed,}) {
  return _then(_Room(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,floorId: null == floorId ? _self.floorId : floorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,targetTempC: null == targetTempC ? _self.targetTempC : targetTempC // ignore: cast_nullable_to_non_nullable
as double,airChangeRate: null == airChangeRate ? _self.airChangeRate : airChangeRate // ignore: cast_nullable_to_non_nullable
as double,polygon: null == polygon ? _self._polygon : polygon // ignore: cast_nullable_to_non_nullable
as List<Point2D>,floorConstructionId: freezed == floorConstructionId ? _self.floorConstructionId : floorConstructionId // ignore: cast_nullable_to_non_nullable
as String?,ceilingConstructionId: freezed == ceilingConstructionId ? _self.ceilingConstructionId : ceilingConstructionId // ignore: cast_nullable_to_non_nullable
as String?,floorBoundary: null == floorBoundary ? _self.floorBoundary : floorBoundary // ignore: cast_nullable_to_non_nullable
as BoundaryCondition,ceilingBoundary: null == ceilingBoundary ? _self.ceilingBoundary : ceilingBoundary // ignore: cast_nullable_to_non_nullable
as BoundaryCondition,floorAdjacentTempC: freezed == floorAdjacentTempC ? _self.floorAdjacentTempC : floorAdjacentTempC // ignore: cast_nullable_to_non_nullable
as double?,ceilingAdjacentTempC: freezed == ceilingAdjacentTempC ? _self.ceilingAdjacentTempC : ceilingAdjacentTempC // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
