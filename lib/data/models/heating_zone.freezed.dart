// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'heating_zone.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HeatingZone {

/// UUID v4 primary key.
 String get id;/// UUID of the parent [Room].
 String get roomId;/// Whether this is a floor-heating or wall-heating zone.
 ZoneType get zoneType;/// Zone boundary polygon in millimetre coordinates (≥ 3 vertices).
 List<Point2D> get polygon;/// Centre-to-centre pipe spacing in millimetres. Range: 50–400.
 int get tubeSpacingMm;/// UUID of the [TubeType] used in this zone.
 String get tubeTypeId;/// UUID of the [FlooringMaterial] covering this zone.
 String get flooringMaterialId;/// Minimum distance from wall edge to first pipe run, in mm.
/// Range: 50–300.
 int get borderDistanceMm;/// Pipe routing pattern within the zone.
 LayoutPattern get layoutPattern;/// UUID of the assigned [HeatingCircuit]; null until connected.
 String? get circuitId;/// UUID of the host [WallSegment].
///
/// Required when [zoneType] is [ZoneType.wallHeating]; null for
/// [ZoneType.floorHeating].
 String? get wallSegmentId;/// Height of the wall heating zone in millimetres.
///
/// Required when [zoneType] is [ZoneType.wallHeating]. Must be in
/// the range 300 to the parent floor's [Floor.heightMm].
/// Defaults to the floor's [Floor.heightMm] when not set.
 int? get heightMm;/// Offset from the wall start endpoint to the zone's left edge (mm).
///
/// Null for [ZoneType.floorHeating]. For wall zones, defaults to 0.0
/// (zone starts at the wall start). Range: 0 to wallLength − [widthMm].
 double? get positionOnWallMm;/// Length of the zone along the wall in millimetres.
///
/// Null for [ZoneType.floorHeating]. For wall zones, null means
/// the zone spans the full wall length. Range: 50 to wallLength.
 int? get widthMm;/// User-specified thermal resistance in m²·K/W.
///
/// Only meaningful when [flooringMaterialId] equals
/// [kCustomFlooringMaterialId]. Range: 0.000–0.500. Null until
/// the user sets a value.
 double? get customFlooringResistance;
/// Create a copy of HeatingZone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeatingZoneCopyWith<HeatingZone> get copyWith => _$HeatingZoneCopyWithImpl<HeatingZone>(this as HeatingZone, _$identity);

  /// Serializes this HeatingZone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeatingZone&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.zoneType, zoneType) || other.zoneType == zoneType)&&const DeepCollectionEquality().equals(other.polygon, polygon)&&(identical(other.tubeSpacingMm, tubeSpacingMm) || other.tubeSpacingMm == tubeSpacingMm)&&(identical(other.tubeTypeId, tubeTypeId) || other.tubeTypeId == tubeTypeId)&&(identical(other.flooringMaterialId, flooringMaterialId) || other.flooringMaterialId == flooringMaterialId)&&(identical(other.borderDistanceMm, borderDistanceMm) || other.borderDistanceMm == borderDistanceMm)&&(identical(other.layoutPattern, layoutPattern) || other.layoutPattern == layoutPattern)&&(identical(other.circuitId, circuitId) || other.circuitId == circuitId)&&(identical(other.wallSegmentId, wallSegmentId) || other.wallSegmentId == wallSegmentId)&&(identical(other.heightMm, heightMm) || other.heightMm == heightMm)&&(identical(other.positionOnWallMm, positionOnWallMm) || other.positionOnWallMm == positionOnWallMm)&&(identical(other.widthMm, widthMm) || other.widthMm == widthMm)&&(identical(other.customFlooringResistance, customFlooringResistance) || other.customFlooringResistance == customFlooringResistance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,zoneType,const DeepCollectionEquality().hash(polygon),tubeSpacingMm,tubeTypeId,flooringMaterialId,borderDistanceMm,layoutPattern,circuitId,wallSegmentId,heightMm,positionOnWallMm,widthMm,customFlooringResistance);

@override
String toString() {
  return 'HeatingZone(id: $id, roomId: $roomId, zoneType: $zoneType, polygon: $polygon, tubeSpacingMm: $tubeSpacingMm, tubeTypeId: $tubeTypeId, flooringMaterialId: $flooringMaterialId, borderDistanceMm: $borderDistanceMm, layoutPattern: $layoutPattern, circuitId: $circuitId, wallSegmentId: $wallSegmentId, heightMm: $heightMm, positionOnWallMm: $positionOnWallMm, widthMm: $widthMm, customFlooringResistance: $customFlooringResistance)';
}


}

/// @nodoc
abstract mixin class $HeatingZoneCopyWith<$Res>  {
  factory $HeatingZoneCopyWith(HeatingZone value, $Res Function(HeatingZone) _then) = _$HeatingZoneCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, ZoneType zoneType, List<Point2D> polygon, int tubeSpacingMm, String tubeTypeId, String flooringMaterialId, int borderDistanceMm, LayoutPattern layoutPattern, String? circuitId, String? wallSegmentId, int? heightMm, double? positionOnWallMm, int? widthMm, double? customFlooringResistance
});




}
/// @nodoc
class _$HeatingZoneCopyWithImpl<$Res>
    implements $HeatingZoneCopyWith<$Res> {
  _$HeatingZoneCopyWithImpl(this._self, this._then);

  final HeatingZone _self;
  final $Res Function(HeatingZone) _then;

/// Create a copy of HeatingZone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? zoneType = null,Object? polygon = null,Object? tubeSpacingMm = null,Object? tubeTypeId = null,Object? flooringMaterialId = null,Object? borderDistanceMm = null,Object? layoutPattern = null,Object? circuitId = freezed,Object? wallSegmentId = freezed,Object? heightMm = freezed,Object? positionOnWallMm = freezed,Object? widthMm = freezed,Object? customFlooringResistance = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,zoneType: null == zoneType ? _self.zoneType : zoneType // ignore: cast_nullable_to_non_nullable
as ZoneType,polygon: null == polygon ? _self.polygon : polygon // ignore: cast_nullable_to_non_nullable
as List<Point2D>,tubeSpacingMm: null == tubeSpacingMm ? _self.tubeSpacingMm : tubeSpacingMm // ignore: cast_nullable_to_non_nullable
as int,tubeTypeId: null == tubeTypeId ? _self.tubeTypeId : tubeTypeId // ignore: cast_nullable_to_non_nullable
as String,flooringMaterialId: null == flooringMaterialId ? _self.flooringMaterialId : flooringMaterialId // ignore: cast_nullable_to_non_nullable
as String,borderDistanceMm: null == borderDistanceMm ? _self.borderDistanceMm : borderDistanceMm // ignore: cast_nullable_to_non_nullable
as int,layoutPattern: null == layoutPattern ? _self.layoutPattern : layoutPattern // ignore: cast_nullable_to_non_nullable
as LayoutPattern,circuitId: freezed == circuitId ? _self.circuitId : circuitId // ignore: cast_nullable_to_non_nullable
as String?,wallSegmentId: freezed == wallSegmentId ? _self.wallSegmentId : wallSegmentId // ignore: cast_nullable_to_non_nullable
as String?,heightMm: freezed == heightMm ? _self.heightMm : heightMm // ignore: cast_nullable_to_non_nullable
as int?,positionOnWallMm: freezed == positionOnWallMm ? _self.positionOnWallMm : positionOnWallMm // ignore: cast_nullable_to_non_nullable
as double?,widthMm: freezed == widthMm ? _self.widthMm : widthMm // ignore: cast_nullable_to_non_nullable
as int?,customFlooringResistance: freezed == customFlooringResistance ? _self.customFlooringResistance : customFlooringResistance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [HeatingZone].
extension HeatingZonePatterns on HeatingZone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeatingZone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeatingZone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeatingZone value)  $default,){
final _that = this;
switch (_that) {
case _HeatingZone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeatingZone value)?  $default,){
final _that = this;
switch (_that) {
case _HeatingZone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  ZoneType zoneType,  List<Point2D> polygon,  int tubeSpacingMm,  String tubeTypeId,  String flooringMaterialId,  int borderDistanceMm,  LayoutPattern layoutPattern,  String? circuitId,  String? wallSegmentId,  int? heightMm,  double? positionOnWallMm,  int? widthMm,  double? customFlooringResistance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeatingZone() when $default != null:
return $default(_that.id,_that.roomId,_that.zoneType,_that.polygon,_that.tubeSpacingMm,_that.tubeTypeId,_that.flooringMaterialId,_that.borderDistanceMm,_that.layoutPattern,_that.circuitId,_that.wallSegmentId,_that.heightMm,_that.positionOnWallMm,_that.widthMm,_that.customFlooringResistance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  ZoneType zoneType,  List<Point2D> polygon,  int tubeSpacingMm,  String tubeTypeId,  String flooringMaterialId,  int borderDistanceMm,  LayoutPattern layoutPattern,  String? circuitId,  String? wallSegmentId,  int? heightMm,  double? positionOnWallMm,  int? widthMm,  double? customFlooringResistance)  $default,) {final _that = this;
switch (_that) {
case _HeatingZone():
return $default(_that.id,_that.roomId,_that.zoneType,_that.polygon,_that.tubeSpacingMm,_that.tubeTypeId,_that.flooringMaterialId,_that.borderDistanceMm,_that.layoutPattern,_that.circuitId,_that.wallSegmentId,_that.heightMm,_that.positionOnWallMm,_that.widthMm,_that.customFlooringResistance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  ZoneType zoneType,  List<Point2D> polygon,  int tubeSpacingMm,  String tubeTypeId,  String flooringMaterialId,  int borderDistanceMm,  LayoutPattern layoutPattern,  String? circuitId,  String? wallSegmentId,  int? heightMm,  double? positionOnWallMm,  int? widthMm,  double? customFlooringResistance)?  $default,) {final _that = this;
switch (_that) {
case _HeatingZone() when $default != null:
return $default(_that.id,_that.roomId,_that.zoneType,_that.polygon,_that.tubeSpacingMm,_that.tubeTypeId,_that.flooringMaterialId,_that.borderDistanceMm,_that.layoutPattern,_that.circuitId,_that.wallSegmentId,_that.heightMm,_that.positionOnWallMm,_that.widthMm,_that.customFlooringResistance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HeatingZone implements HeatingZone {
  const _HeatingZone({required this.id, required this.roomId, this.zoneType = ZoneType.floorHeating, final  List<Point2D> polygon = const [], this.tubeSpacingMm = 150, required this.tubeTypeId, required this.flooringMaterialId, this.borderDistanceMm = 100, this.layoutPattern = LayoutPattern.meander, this.circuitId, this.wallSegmentId, this.heightMm, this.positionOnWallMm, this.widthMm, this.customFlooringResistance}): _polygon = polygon;
  factory _HeatingZone.fromJson(Map<String, dynamic> json) => _$HeatingZoneFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the parent [Room].
@override final  String roomId;
/// Whether this is a floor-heating or wall-heating zone.
@override@JsonKey() final  ZoneType zoneType;
/// Zone boundary polygon in millimetre coordinates (≥ 3 vertices).
 final  List<Point2D> _polygon;
/// Zone boundary polygon in millimetre coordinates (≥ 3 vertices).
@override@JsonKey() List<Point2D> get polygon {
  if (_polygon is EqualUnmodifiableListView) return _polygon;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_polygon);
}

/// Centre-to-centre pipe spacing in millimetres. Range: 50–400.
@override@JsonKey() final  int tubeSpacingMm;
/// UUID of the [TubeType] used in this zone.
@override final  String tubeTypeId;
/// UUID of the [FlooringMaterial] covering this zone.
@override final  String flooringMaterialId;
/// Minimum distance from wall edge to first pipe run, in mm.
/// Range: 50–300.
@override@JsonKey() final  int borderDistanceMm;
/// Pipe routing pattern within the zone.
@override@JsonKey() final  LayoutPattern layoutPattern;
/// UUID of the assigned [HeatingCircuit]; null until connected.
@override final  String? circuitId;
/// UUID of the host [WallSegment].
///
/// Required when [zoneType] is [ZoneType.wallHeating]; null for
/// [ZoneType.floorHeating].
@override final  String? wallSegmentId;
/// Height of the wall heating zone in millimetres.
///
/// Required when [zoneType] is [ZoneType.wallHeating]. Must be in
/// the range 300 to the parent floor's [Floor.heightMm].
/// Defaults to the floor's [Floor.heightMm] when not set.
@override final  int? heightMm;
/// Offset from the wall start endpoint to the zone's left edge (mm).
///
/// Null for [ZoneType.floorHeating]. For wall zones, defaults to 0.0
/// (zone starts at the wall start). Range: 0 to wallLength − [widthMm].
@override final  double? positionOnWallMm;
/// Length of the zone along the wall in millimetres.
///
/// Null for [ZoneType.floorHeating]. For wall zones, null means
/// the zone spans the full wall length. Range: 50 to wallLength.
@override final  int? widthMm;
/// User-specified thermal resistance in m²·K/W.
///
/// Only meaningful when [flooringMaterialId] equals
/// [kCustomFlooringMaterialId]. Range: 0.000–0.500. Null until
/// the user sets a value.
@override final  double? customFlooringResistance;

/// Create a copy of HeatingZone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeatingZoneCopyWith<_HeatingZone> get copyWith => __$HeatingZoneCopyWithImpl<_HeatingZone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeatingZoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeatingZone&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.zoneType, zoneType) || other.zoneType == zoneType)&&const DeepCollectionEquality().equals(other._polygon, _polygon)&&(identical(other.tubeSpacingMm, tubeSpacingMm) || other.tubeSpacingMm == tubeSpacingMm)&&(identical(other.tubeTypeId, tubeTypeId) || other.tubeTypeId == tubeTypeId)&&(identical(other.flooringMaterialId, flooringMaterialId) || other.flooringMaterialId == flooringMaterialId)&&(identical(other.borderDistanceMm, borderDistanceMm) || other.borderDistanceMm == borderDistanceMm)&&(identical(other.layoutPattern, layoutPattern) || other.layoutPattern == layoutPattern)&&(identical(other.circuitId, circuitId) || other.circuitId == circuitId)&&(identical(other.wallSegmentId, wallSegmentId) || other.wallSegmentId == wallSegmentId)&&(identical(other.heightMm, heightMm) || other.heightMm == heightMm)&&(identical(other.positionOnWallMm, positionOnWallMm) || other.positionOnWallMm == positionOnWallMm)&&(identical(other.widthMm, widthMm) || other.widthMm == widthMm)&&(identical(other.customFlooringResistance, customFlooringResistance) || other.customFlooringResistance == customFlooringResistance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,zoneType,const DeepCollectionEquality().hash(_polygon),tubeSpacingMm,tubeTypeId,flooringMaterialId,borderDistanceMm,layoutPattern,circuitId,wallSegmentId,heightMm,positionOnWallMm,widthMm,customFlooringResistance);

@override
String toString() {
  return 'HeatingZone(id: $id, roomId: $roomId, zoneType: $zoneType, polygon: $polygon, tubeSpacingMm: $tubeSpacingMm, tubeTypeId: $tubeTypeId, flooringMaterialId: $flooringMaterialId, borderDistanceMm: $borderDistanceMm, layoutPattern: $layoutPattern, circuitId: $circuitId, wallSegmentId: $wallSegmentId, heightMm: $heightMm, positionOnWallMm: $positionOnWallMm, widthMm: $widthMm, customFlooringResistance: $customFlooringResistance)';
}


}

/// @nodoc
abstract mixin class _$HeatingZoneCopyWith<$Res> implements $HeatingZoneCopyWith<$Res> {
  factory _$HeatingZoneCopyWith(_HeatingZone value, $Res Function(_HeatingZone) _then) = __$HeatingZoneCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, ZoneType zoneType, List<Point2D> polygon, int tubeSpacingMm, String tubeTypeId, String flooringMaterialId, int borderDistanceMm, LayoutPattern layoutPattern, String? circuitId, String? wallSegmentId, int? heightMm, double? positionOnWallMm, int? widthMm, double? customFlooringResistance
});




}
/// @nodoc
class __$HeatingZoneCopyWithImpl<$Res>
    implements _$HeatingZoneCopyWith<$Res> {
  __$HeatingZoneCopyWithImpl(this._self, this._then);

  final _HeatingZone _self;
  final $Res Function(_HeatingZone) _then;

/// Create a copy of HeatingZone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? zoneType = null,Object? polygon = null,Object? tubeSpacingMm = null,Object? tubeTypeId = null,Object? flooringMaterialId = null,Object? borderDistanceMm = null,Object? layoutPattern = null,Object? circuitId = freezed,Object? wallSegmentId = freezed,Object? heightMm = freezed,Object? positionOnWallMm = freezed,Object? widthMm = freezed,Object? customFlooringResistance = freezed,}) {
  return _then(_HeatingZone(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,zoneType: null == zoneType ? _self.zoneType : zoneType // ignore: cast_nullable_to_non_nullable
as ZoneType,polygon: null == polygon ? _self._polygon : polygon // ignore: cast_nullable_to_non_nullable
as List<Point2D>,tubeSpacingMm: null == tubeSpacingMm ? _self.tubeSpacingMm : tubeSpacingMm // ignore: cast_nullable_to_non_nullable
as int,tubeTypeId: null == tubeTypeId ? _self.tubeTypeId : tubeTypeId // ignore: cast_nullable_to_non_nullable
as String,flooringMaterialId: null == flooringMaterialId ? _self.flooringMaterialId : flooringMaterialId // ignore: cast_nullable_to_non_nullable
as String,borderDistanceMm: null == borderDistanceMm ? _self.borderDistanceMm : borderDistanceMm // ignore: cast_nullable_to_non_nullable
as int,layoutPattern: null == layoutPattern ? _self.layoutPattern : layoutPattern // ignore: cast_nullable_to_non_nullable
as LayoutPattern,circuitId: freezed == circuitId ? _self.circuitId : circuitId // ignore: cast_nullable_to_non_nullable
as String?,wallSegmentId: freezed == wallSegmentId ? _self.wallSegmentId : wallSegmentId // ignore: cast_nullable_to_non_nullable
as String?,heightMm: freezed == heightMm ? _self.heightMm : heightMm // ignore: cast_nullable_to_non_nullable
as int?,positionOnWallMm: freezed == positionOnWallMm ? _self.positionOnWallMm : positionOnWallMm // ignore: cast_nullable_to_non_nullable
as double?,widthMm: freezed == widthMm ? _self.widthMm : widthMm // ignore: cast_nullable_to_non_nullable
as int?,customFlooringResistance: freezed == customFlooringResistance ? _self.customFlooringResistance : customFlooringResistance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
