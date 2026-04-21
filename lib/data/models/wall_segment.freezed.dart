// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wall_segment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WallSegment {

/// UUID v4 primary key.
 String get id;/// UUID of the owning [Room].
 String get roomId;/// Start vertex in millimetre coordinates.
 Point2D get startPoint;/// End vertex in millimetre coordinates.
 Point2D get endPoint;/// Thermal and structural classification.
 WallType get wallType;/// UUID of the associated [WallConstruction]; null if unassigned.
 String? get constructionId;/// UUID of the room on the other side; null for exterior walls.
 String? get adjacentRoomId;/// Compass orientation derived from segment angle.
 CardinalDirection get orientation;/// UUID of the mirror wall in an ADR-001 shared-wall pair.
///
/// Set by [addRoomFromDetection] when the interior copy is created.
/// Null for exterior and unassigned walls.
 String? get mirrorId;
/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallSegmentCopyWith<WallSegment> get copyWith => _$WallSegmentCopyWithImpl<WallSegment>(this as WallSegment, _$identity);

  /// Serializes this WallSegment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallSegment&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.startPoint, startPoint) || other.startPoint == startPoint)&&(identical(other.endPoint, endPoint) || other.endPoint == endPoint)&&(identical(other.wallType, wallType) || other.wallType == wallType)&&(identical(other.constructionId, constructionId) || other.constructionId == constructionId)&&(identical(other.adjacentRoomId, adjacentRoomId) || other.adjacentRoomId == adjacentRoomId)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.mirrorId, mirrorId) || other.mirrorId == mirrorId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,startPoint,endPoint,wallType,constructionId,adjacentRoomId,orientation,mirrorId);

@override
String toString() {
  return 'WallSegment(id: $id, roomId: $roomId, startPoint: $startPoint, endPoint: $endPoint, wallType: $wallType, constructionId: $constructionId, adjacentRoomId: $adjacentRoomId, orientation: $orientation, mirrorId: $mirrorId)';
}


}

/// @nodoc
abstract mixin class $WallSegmentCopyWith<$Res>  {
  factory $WallSegmentCopyWith(WallSegment value, $Res Function(WallSegment) _then) = _$WallSegmentCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, Point2D startPoint, Point2D endPoint, WallType wallType, String? constructionId, String? adjacentRoomId, CardinalDirection orientation, String? mirrorId
});


$Point2DCopyWith<$Res> get startPoint;$Point2DCopyWith<$Res> get endPoint;

}
/// @nodoc
class _$WallSegmentCopyWithImpl<$Res>
    implements $WallSegmentCopyWith<$Res> {
  _$WallSegmentCopyWithImpl(this._self, this._then);

  final WallSegment _self;
  final $Res Function(WallSegment) _then;

/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? startPoint = null,Object? endPoint = null,Object? wallType = null,Object? constructionId = freezed,Object? adjacentRoomId = freezed,Object? orientation = null,Object? mirrorId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,startPoint: null == startPoint ? _self.startPoint : startPoint // ignore: cast_nullable_to_non_nullable
as Point2D,endPoint: null == endPoint ? _self.endPoint : endPoint // ignore: cast_nullable_to_non_nullable
as Point2D,wallType: null == wallType ? _self.wallType : wallType // ignore: cast_nullable_to_non_nullable
as WallType,constructionId: freezed == constructionId ? _self.constructionId : constructionId // ignore: cast_nullable_to_non_nullable
as String?,adjacentRoomId: freezed == adjacentRoomId ? _self.adjacentRoomId : adjacentRoomId // ignore: cast_nullable_to_non_nullable
as String?,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as CardinalDirection,mirrorId: freezed == mirrorId ? _self.mirrorId : mirrorId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get startPoint {
  
  return $Point2DCopyWith<$Res>(_self.startPoint, (value) {
    return _then(_self.copyWith(startPoint: value));
  });
}/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get endPoint {
  
  return $Point2DCopyWith<$Res>(_self.endPoint, (value) {
    return _then(_self.copyWith(endPoint: value));
  });
}
}


/// Adds pattern-matching-related methods to [WallSegment].
extension WallSegmentPatterns on WallSegment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallSegment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallSegment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallSegment value)  $default,){
final _that = this;
switch (_that) {
case _WallSegment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallSegment value)?  $default,){
final _that = this;
switch (_that) {
case _WallSegment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  Point2D startPoint,  Point2D endPoint,  WallType wallType,  String? constructionId,  String? adjacentRoomId,  CardinalDirection orientation,  String? mirrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallSegment() when $default != null:
return $default(_that.id,_that.roomId,_that.startPoint,_that.endPoint,_that.wallType,_that.constructionId,_that.adjacentRoomId,_that.orientation,_that.mirrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  Point2D startPoint,  Point2D endPoint,  WallType wallType,  String? constructionId,  String? adjacentRoomId,  CardinalDirection orientation,  String? mirrorId)  $default,) {final _that = this;
switch (_that) {
case _WallSegment():
return $default(_that.id,_that.roomId,_that.startPoint,_that.endPoint,_that.wallType,_that.constructionId,_that.adjacentRoomId,_that.orientation,_that.mirrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  Point2D startPoint,  Point2D endPoint,  WallType wallType,  String? constructionId,  String? adjacentRoomId,  CardinalDirection orientation,  String? mirrorId)?  $default,) {final _that = this;
switch (_that) {
case _WallSegment() when $default != null:
return $default(_that.id,_that.roomId,_that.startPoint,_that.endPoint,_that.wallType,_that.constructionId,_that.adjacentRoomId,_that.orientation,_that.mirrorId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallSegment implements WallSegment {
  const _WallSegment({required this.id, required this.roomId, required this.startPoint, required this.endPoint, this.wallType = WallType.exterior, this.constructionId, this.adjacentRoomId, this.orientation = CardinalDirection.north, this.mirrorId});
  factory _WallSegment.fromJson(Map<String, dynamic> json) => _$WallSegmentFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the owning [Room].
@override final  String roomId;
/// Start vertex in millimetre coordinates.
@override final  Point2D startPoint;
/// End vertex in millimetre coordinates.
@override final  Point2D endPoint;
/// Thermal and structural classification.
@override@JsonKey() final  WallType wallType;
/// UUID of the associated [WallConstruction]; null if unassigned.
@override final  String? constructionId;
/// UUID of the room on the other side; null for exterior walls.
@override final  String? adjacentRoomId;
/// Compass orientation derived from segment angle.
@override@JsonKey() final  CardinalDirection orientation;
/// UUID of the mirror wall in an ADR-001 shared-wall pair.
///
/// Set by [addRoomFromDetection] when the interior copy is created.
/// Null for exterior and unassigned walls.
@override final  String? mirrorId;

/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallSegmentCopyWith<_WallSegment> get copyWith => __$WallSegmentCopyWithImpl<_WallSegment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallSegmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallSegment&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.startPoint, startPoint) || other.startPoint == startPoint)&&(identical(other.endPoint, endPoint) || other.endPoint == endPoint)&&(identical(other.wallType, wallType) || other.wallType == wallType)&&(identical(other.constructionId, constructionId) || other.constructionId == constructionId)&&(identical(other.adjacentRoomId, adjacentRoomId) || other.adjacentRoomId == adjacentRoomId)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.mirrorId, mirrorId) || other.mirrorId == mirrorId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,startPoint,endPoint,wallType,constructionId,adjacentRoomId,orientation,mirrorId);

@override
String toString() {
  return 'WallSegment(id: $id, roomId: $roomId, startPoint: $startPoint, endPoint: $endPoint, wallType: $wallType, constructionId: $constructionId, adjacentRoomId: $adjacentRoomId, orientation: $orientation, mirrorId: $mirrorId)';
}


}

/// @nodoc
abstract mixin class _$WallSegmentCopyWith<$Res> implements $WallSegmentCopyWith<$Res> {
  factory _$WallSegmentCopyWith(_WallSegment value, $Res Function(_WallSegment) _then) = __$WallSegmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, Point2D startPoint, Point2D endPoint, WallType wallType, String? constructionId, String? adjacentRoomId, CardinalDirection orientation, String? mirrorId
});


@override $Point2DCopyWith<$Res> get startPoint;@override $Point2DCopyWith<$Res> get endPoint;

}
/// @nodoc
class __$WallSegmentCopyWithImpl<$Res>
    implements _$WallSegmentCopyWith<$Res> {
  __$WallSegmentCopyWithImpl(this._self, this._then);

  final _WallSegment _self;
  final $Res Function(_WallSegment) _then;

/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? startPoint = null,Object? endPoint = null,Object? wallType = null,Object? constructionId = freezed,Object? adjacentRoomId = freezed,Object? orientation = null,Object? mirrorId = freezed,}) {
  return _then(_WallSegment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,startPoint: null == startPoint ? _self.startPoint : startPoint // ignore: cast_nullable_to_non_nullable
as Point2D,endPoint: null == endPoint ? _self.endPoint : endPoint // ignore: cast_nullable_to_non_nullable
as Point2D,wallType: null == wallType ? _self.wallType : wallType // ignore: cast_nullable_to_non_nullable
as WallType,constructionId: freezed == constructionId ? _self.constructionId : constructionId // ignore: cast_nullable_to_non_nullable
as String?,adjacentRoomId: freezed == adjacentRoomId ? _self.adjacentRoomId : adjacentRoomId // ignore: cast_nullable_to_non_nullable
as String?,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as CardinalDirection,mirrorId: freezed == mirrorId ? _self.mirrorId : mirrorId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get startPoint {
  
  return $Point2DCopyWith<$Res>(_self.startPoint, (value) {
    return _then(_self.copyWith(startPoint: value));
  });
}/// Create a copy of WallSegment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Point2DCopyWith<$Res> get endPoint {
  
  return $Point2DCopyWith<$Res>(_self.endPoint, (value) {
    return _then(_self.copyWith(endPoint: value));
  });
}
}

// dart format on
