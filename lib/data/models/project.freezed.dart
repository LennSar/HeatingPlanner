// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeoLocation {

 double get latitude; double get longitude; String? get cityName;
/// Create a copy of GeoLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoLocationCopyWith<GeoLocation> get copyWith => _$GeoLocationCopyWithImpl<GeoLocation>(this as GeoLocation, _$identity);

  /// Serializes this GeoLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoLocation&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.cityName, cityName) || other.cityName == cityName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,cityName);

@override
String toString() {
  return 'GeoLocation(latitude: $latitude, longitude: $longitude, cityName: $cityName)';
}


}

/// @nodoc
abstract mixin class $GeoLocationCopyWith<$Res>  {
  factory $GeoLocationCopyWith(GeoLocation value, $Res Function(GeoLocation) _then) = _$GeoLocationCopyWithImpl;
@useResult
$Res call({
 double latitude, double longitude, String? cityName
});




}
/// @nodoc
class _$GeoLocationCopyWithImpl<$Res>
    implements $GeoLocationCopyWith<$Res> {
  _$GeoLocationCopyWithImpl(this._self, this._then);

  final GeoLocation _self;
  final $Res Function(GeoLocation) _then;

/// Create a copy of GeoLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = null,Object? longitude = null,Object? cityName = freezed,}) {
  return _then(_self.copyWith(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,cityName: freezed == cityName ? _self.cityName : cityName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoLocation].
extension GeoLocationPatterns on GeoLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoLocation value)  $default,){
final _that = this;
switch (_that) {
case _GeoLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoLocation value)?  $default,){
final _that = this;
switch (_that) {
case _GeoLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double latitude,  double longitude,  String? cityName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoLocation() when $default != null:
return $default(_that.latitude,_that.longitude,_that.cityName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double latitude,  double longitude,  String? cityName)  $default,) {final _that = this;
switch (_that) {
case _GeoLocation():
return $default(_that.latitude,_that.longitude,_that.cityName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double latitude,  double longitude,  String? cityName)?  $default,) {final _that = this;
switch (_that) {
case _GeoLocation() when $default != null:
return $default(_that.latitude,_that.longitude,_that.cityName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeoLocation implements GeoLocation {
  const _GeoLocation({required this.latitude, required this.longitude, this.cityName});
  factory _GeoLocation.fromJson(Map<String, dynamic> json) => _$GeoLocationFromJson(json);

@override final  double latitude;
@override final  double longitude;
@override final  String? cityName;

/// Create a copy of GeoLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoLocationCopyWith<_GeoLocation> get copyWith => __$GeoLocationCopyWithImpl<_GeoLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeoLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoLocation&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.cityName, cityName) || other.cityName == cityName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,cityName);

@override
String toString() {
  return 'GeoLocation(latitude: $latitude, longitude: $longitude, cityName: $cityName)';
}


}

/// @nodoc
abstract mixin class _$GeoLocationCopyWith<$Res> implements $GeoLocationCopyWith<$Res> {
  factory _$GeoLocationCopyWith(_GeoLocation value, $Res Function(_GeoLocation) _then) = __$GeoLocationCopyWithImpl;
@override @useResult
$Res call({
 double latitude, double longitude, String? cityName
});




}
/// @nodoc
class __$GeoLocationCopyWithImpl<$Res>
    implements _$GeoLocationCopyWith<$Res> {
  __$GeoLocationCopyWithImpl(this._self, this._then);

  final _GeoLocation _self;
  final $Res Function(_GeoLocation) _then;

/// Create a copy of GeoLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = null,Object? longitude = null,Object? cityName = freezed,}) {
  return _then(_GeoLocation(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,cityName: freezed == cityName ? _self.cityName : cityName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Project {

/// UUID v4 primary key.
 String get id;/// Human-readable project name (1–255 chars).
 String get name;/// Timestamp when the project was first created (immutable).
 DateTime get createdAt;/// Timestamp of the last modification.
 DateTime get modifiedAt;/// Outdoor design temperature in °C for heat-demand calculations.
 double get designOutdoorTempC;/// Default indoor target temperature in °C (applied to new rooms).
 double get defaultIndoorTempC;/// Default floor-to-ceiling height in mm (2000–6000).
 int get floorHeightMm;/// Default temperature of unheated adjacent spaces in °C (0–25).
 double get unheatedSpaceTempC;/// Default total thickness in mm for exterior walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for exterior walls
/// whose `constructionId` is null. Constraint: 50–1000.
 int get defaultExteriorWallThicknessMm;/// Default total thickness in mm for interior (shared) walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for interior walls
/// whose `constructionId` is null. Constraint: 50–1000.
 int get defaultInteriorWallThicknessMm;/// Default total thickness in mm for partition walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for partition walls
/// whose `constructionId` is null. Constraint: 50–1000.
 int get defaultPartitionWallThicknessMm;/// Default material catalog entry ID used for the single auto-default
/// layer of every freshly drawn exterior wall (ADR-020 Rule 1).
///
/// Initial value points at the "Vertical coring brick" entry
/// (`mat-016`) in `assets/materials.json`. Editing this field in the
/// project settings cascades to every wall whose construction has
/// `isAutoDefault = true` per ADR-020 Rule 6.
 String get defaultExteriorMaterialId;/// Default material catalog entry ID for new interior (shared) walls.
///
/// See [defaultExteriorMaterialId] for cascade semantics.
 String get defaultInteriorMaterialId;/// Default material catalog entry ID for new partition walls.
///
/// See [defaultExteriorMaterialId] for cascade semantics.
 String get defaultPartitionMaterialId;/// Optional geographic location used for climate data lookup.
 GeoLocation? get location;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt)&&(identical(other.designOutdoorTempC, designOutdoorTempC) || other.designOutdoorTempC == designOutdoorTempC)&&(identical(other.defaultIndoorTempC, defaultIndoorTempC) || other.defaultIndoorTempC == defaultIndoorTempC)&&(identical(other.floorHeightMm, floorHeightMm) || other.floorHeightMm == floorHeightMm)&&(identical(other.unheatedSpaceTempC, unheatedSpaceTempC) || other.unheatedSpaceTempC == unheatedSpaceTempC)&&(identical(other.defaultExteriorWallThicknessMm, defaultExteriorWallThicknessMm) || other.defaultExteriorWallThicknessMm == defaultExteriorWallThicknessMm)&&(identical(other.defaultInteriorWallThicknessMm, defaultInteriorWallThicknessMm) || other.defaultInteriorWallThicknessMm == defaultInteriorWallThicknessMm)&&(identical(other.defaultPartitionWallThicknessMm, defaultPartitionWallThicknessMm) || other.defaultPartitionWallThicknessMm == defaultPartitionWallThicknessMm)&&(identical(other.defaultExteriorMaterialId, defaultExteriorMaterialId) || other.defaultExteriorMaterialId == defaultExteriorMaterialId)&&(identical(other.defaultInteriorMaterialId, defaultInteriorMaterialId) || other.defaultInteriorMaterialId == defaultInteriorMaterialId)&&(identical(other.defaultPartitionMaterialId, defaultPartitionMaterialId) || other.defaultPartitionMaterialId == defaultPartitionMaterialId)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,createdAt,modifiedAt,designOutdoorTempC,defaultIndoorTempC,floorHeightMm,unheatedSpaceTempC,defaultExteriorWallThicknessMm,defaultInteriorWallThicknessMm,defaultPartitionWallThicknessMm,defaultExteriorMaterialId,defaultInteriorMaterialId,defaultPartitionMaterialId,location);

@override
String toString() {
  return 'Project(id: $id, name: $name, createdAt: $createdAt, modifiedAt: $modifiedAt, designOutdoorTempC: $designOutdoorTempC, defaultIndoorTempC: $defaultIndoorTempC, floorHeightMm: $floorHeightMm, unheatedSpaceTempC: $unheatedSpaceTempC, defaultExteriorWallThicknessMm: $defaultExteriorWallThicknessMm, defaultInteriorWallThicknessMm: $defaultInteriorWallThicknessMm, defaultPartitionWallThicknessMm: $defaultPartitionWallThicknessMm, defaultExteriorMaterialId: $defaultExteriorMaterialId, defaultInteriorMaterialId: $defaultInteriorMaterialId, defaultPartitionMaterialId: $defaultPartitionMaterialId, location: $location)';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime modifiedAt, double designOutdoorTempC, double defaultIndoorTempC, int floorHeightMm, double unheatedSpaceTempC, int defaultExteriorWallThicknessMm, int defaultInteriorWallThicknessMm, int defaultPartitionWallThicknessMm, String defaultExteriorMaterialId, String defaultInteriorMaterialId, String defaultPartitionMaterialId, GeoLocation? location
});


$GeoLocationCopyWith<$Res>? get location;

}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? modifiedAt = null,Object? designOutdoorTempC = null,Object? defaultIndoorTempC = null,Object? floorHeightMm = null,Object? unheatedSpaceTempC = null,Object? defaultExteriorWallThicknessMm = null,Object? defaultInteriorWallThicknessMm = null,Object? defaultPartitionWallThicknessMm = null,Object? defaultExteriorMaterialId = null,Object? defaultInteriorMaterialId = null,Object? defaultPartitionMaterialId = null,Object? location = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,designOutdoorTempC: null == designOutdoorTempC ? _self.designOutdoorTempC : designOutdoorTempC // ignore: cast_nullable_to_non_nullable
as double,defaultIndoorTempC: null == defaultIndoorTempC ? _self.defaultIndoorTempC : defaultIndoorTempC // ignore: cast_nullable_to_non_nullable
as double,floorHeightMm: null == floorHeightMm ? _self.floorHeightMm : floorHeightMm // ignore: cast_nullable_to_non_nullable
as int,unheatedSpaceTempC: null == unheatedSpaceTempC ? _self.unheatedSpaceTempC : unheatedSpaceTempC // ignore: cast_nullable_to_non_nullable
as double,defaultExteriorWallThicknessMm: null == defaultExteriorWallThicknessMm ? _self.defaultExteriorWallThicknessMm : defaultExteriorWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultInteriorWallThicknessMm: null == defaultInteriorWallThicknessMm ? _self.defaultInteriorWallThicknessMm : defaultInteriorWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultPartitionWallThicknessMm: null == defaultPartitionWallThicknessMm ? _self.defaultPartitionWallThicknessMm : defaultPartitionWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultExteriorMaterialId: null == defaultExteriorMaterialId ? _self.defaultExteriorMaterialId : defaultExteriorMaterialId // ignore: cast_nullable_to_non_nullable
as String,defaultInteriorMaterialId: null == defaultInteriorMaterialId ? _self.defaultInteriorMaterialId : defaultInteriorMaterialId // ignore: cast_nullable_to_non_nullable
as String,defaultPartitionMaterialId: null == defaultPartitionMaterialId ? _self.defaultPartitionMaterialId : defaultPartitionMaterialId // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as GeoLocation?,
  ));
}
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $GeoLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime modifiedAt,  double designOutdoorTempC,  double defaultIndoorTempC,  int floorHeightMm,  double unheatedSpaceTempC,  int defaultExteriorWallThicknessMm,  int defaultInteriorWallThicknessMm,  int defaultPartitionWallThicknessMm,  String defaultExteriorMaterialId,  String defaultInteriorMaterialId,  String defaultPartitionMaterialId,  GeoLocation? location)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.modifiedAt,_that.designOutdoorTempC,_that.defaultIndoorTempC,_that.floorHeightMm,_that.unheatedSpaceTempC,_that.defaultExteriorWallThicknessMm,_that.defaultInteriorWallThicknessMm,_that.defaultPartitionWallThicknessMm,_that.defaultExteriorMaterialId,_that.defaultInteriorMaterialId,_that.defaultPartitionMaterialId,_that.location);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime modifiedAt,  double designOutdoorTempC,  double defaultIndoorTempC,  int floorHeightMm,  double unheatedSpaceTempC,  int defaultExteriorWallThicknessMm,  int defaultInteriorWallThicknessMm,  int defaultPartitionWallThicknessMm,  String defaultExteriorMaterialId,  String defaultInteriorMaterialId,  String defaultPartitionMaterialId,  GeoLocation? location)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.name,_that.createdAt,_that.modifiedAt,_that.designOutdoorTempC,_that.defaultIndoorTempC,_that.floorHeightMm,_that.unheatedSpaceTempC,_that.defaultExteriorWallThicknessMm,_that.defaultInteriorWallThicknessMm,_that.defaultPartitionWallThicknessMm,_that.defaultExteriorMaterialId,_that.defaultInteriorMaterialId,_that.defaultPartitionMaterialId,_that.location);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime createdAt,  DateTime modifiedAt,  double designOutdoorTempC,  double defaultIndoorTempC,  int floorHeightMm,  double unheatedSpaceTempC,  int defaultExteriorWallThicknessMm,  int defaultInteriorWallThicknessMm,  int defaultPartitionWallThicknessMm,  String defaultExteriorMaterialId,  String defaultInteriorMaterialId,  String defaultPartitionMaterialId,  GeoLocation? location)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.modifiedAt,_that.designOutdoorTempC,_that.defaultIndoorTempC,_that.floorHeightMm,_that.unheatedSpaceTempC,_that.defaultExteriorWallThicknessMm,_that.defaultInteriorWallThicknessMm,_that.defaultPartitionWallThicknessMm,_that.defaultExteriorMaterialId,_that.defaultInteriorMaterialId,_that.defaultPartitionMaterialId,_that.location);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Project implements Project {
  const _Project({required this.id, required this.name, required this.createdAt, required this.modifiedAt, this.designOutdoorTempC = -12.0, this.defaultIndoorTempC = 20.0, this.floorHeightMm = 2600, this.unheatedSpaceTempC = 10.0, this.defaultExteriorWallThicknessMm = 240, this.defaultInteriorWallThicknessMm = 120, this.defaultPartitionWallThicknessMm = 100, this.defaultExteriorMaterialId = 'mat-016', this.defaultInteriorMaterialId = 'mat-016', this.defaultPartitionMaterialId = 'mat-016', this.location});
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// Human-readable project name (1–255 chars).
@override final  String name;
/// Timestamp when the project was first created (immutable).
@override final  DateTime createdAt;
/// Timestamp of the last modification.
@override final  DateTime modifiedAt;
/// Outdoor design temperature in °C for heat-demand calculations.
@override@JsonKey() final  double designOutdoorTempC;
/// Default indoor target temperature in °C (applied to new rooms).
@override@JsonKey() final  double defaultIndoorTempC;
/// Default floor-to-ceiling height in mm (2000–6000).
@override@JsonKey() final  int floorHeightMm;
/// Default temperature of unheated adjacent spaces in °C (0–25).
@override@JsonKey() final  double unheatedSpaceTempC;
/// Default total thickness in mm for exterior walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for exterior walls
/// whose `constructionId` is null. Constraint: 50–1000.
@override@JsonKey() final  int defaultExteriorWallThicknessMm;
/// Default total thickness in mm for interior (shared) walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for interior walls
/// whose `constructionId` is null. Constraint: 50–1000.
@override@JsonKey() final  int defaultInteriorWallThicknessMm;
/// Default total thickness in mm for partition walls (ADR-017).
///
/// Used as the fallback `WallSegment.thicknessMm` for partition walls
/// whose `constructionId` is null. Constraint: 50–1000.
@override@JsonKey() final  int defaultPartitionWallThicknessMm;
/// Default material catalog entry ID used for the single auto-default
/// layer of every freshly drawn exterior wall (ADR-020 Rule 1).
///
/// Initial value points at the "Vertical coring brick" entry
/// (`mat-016`) in `assets/materials.json`. Editing this field in the
/// project settings cascades to every wall whose construction has
/// `isAutoDefault = true` per ADR-020 Rule 6.
@override@JsonKey() final  String defaultExteriorMaterialId;
/// Default material catalog entry ID for new interior (shared) walls.
///
/// See [defaultExteriorMaterialId] for cascade semantics.
@override@JsonKey() final  String defaultInteriorMaterialId;
/// Default material catalog entry ID for new partition walls.
///
/// See [defaultExteriorMaterialId] for cascade semantics.
@override@JsonKey() final  String defaultPartitionMaterialId;
/// Optional geographic location used for climate data lookup.
@override final  GeoLocation? location;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt)&&(identical(other.designOutdoorTempC, designOutdoorTempC) || other.designOutdoorTempC == designOutdoorTempC)&&(identical(other.defaultIndoorTempC, defaultIndoorTempC) || other.defaultIndoorTempC == defaultIndoorTempC)&&(identical(other.floorHeightMm, floorHeightMm) || other.floorHeightMm == floorHeightMm)&&(identical(other.unheatedSpaceTempC, unheatedSpaceTempC) || other.unheatedSpaceTempC == unheatedSpaceTempC)&&(identical(other.defaultExteriorWallThicknessMm, defaultExteriorWallThicknessMm) || other.defaultExteriorWallThicknessMm == defaultExteriorWallThicknessMm)&&(identical(other.defaultInteriorWallThicknessMm, defaultInteriorWallThicknessMm) || other.defaultInteriorWallThicknessMm == defaultInteriorWallThicknessMm)&&(identical(other.defaultPartitionWallThicknessMm, defaultPartitionWallThicknessMm) || other.defaultPartitionWallThicknessMm == defaultPartitionWallThicknessMm)&&(identical(other.defaultExteriorMaterialId, defaultExteriorMaterialId) || other.defaultExteriorMaterialId == defaultExteriorMaterialId)&&(identical(other.defaultInteriorMaterialId, defaultInteriorMaterialId) || other.defaultInteriorMaterialId == defaultInteriorMaterialId)&&(identical(other.defaultPartitionMaterialId, defaultPartitionMaterialId) || other.defaultPartitionMaterialId == defaultPartitionMaterialId)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,createdAt,modifiedAt,designOutdoorTempC,defaultIndoorTempC,floorHeightMm,unheatedSpaceTempC,defaultExteriorWallThicknessMm,defaultInteriorWallThicknessMm,defaultPartitionWallThicknessMm,defaultExteriorMaterialId,defaultInteriorMaterialId,defaultPartitionMaterialId,location);

@override
String toString() {
  return 'Project(id: $id, name: $name, createdAt: $createdAt, modifiedAt: $modifiedAt, designOutdoorTempC: $designOutdoorTempC, defaultIndoorTempC: $defaultIndoorTempC, floorHeightMm: $floorHeightMm, unheatedSpaceTempC: $unheatedSpaceTempC, defaultExteriorWallThicknessMm: $defaultExteriorWallThicknessMm, defaultInteriorWallThicknessMm: $defaultInteriorWallThicknessMm, defaultPartitionWallThicknessMm: $defaultPartitionWallThicknessMm, defaultExteriorMaterialId: $defaultExteriorMaterialId, defaultInteriorMaterialId: $defaultInteriorMaterialId, defaultPartitionMaterialId: $defaultPartitionMaterialId, location: $location)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime modifiedAt, double designOutdoorTempC, double defaultIndoorTempC, int floorHeightMm, double unheatedSpaceTempC, int defaultExteriorWallThicknessMm, int defaultInteriorWallThicknessMm, int defaultPartitionWallThicknessMm, String defaultExteriorMaterialId, String defaultInteriorMaterialId, String defaultPartitionMaterialId, GeoLocation? location
});


@override $GeoLocationCopyWith<$Res>? get location;

}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? modifiedAt = null,Object? designOutdoorTempC = null,Object? defaultIndoorTempC = null,Object? floorHeightMm = null,Object? unheatedSpaceTempC = null,Object? defaultExteriorWallThicknessMm = null,Object? defaultInteriorWallThicknessMm = null,Object? defaultPartitionWallThicknessMm = null,Object? defaultExteriorMaterialId = null,Object? defaultInteriorMaterialId = null,Object? defaultPartitionMaterialId = null,Object? location = freezed,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,designOutdoorTempC: null == designOutdoorTempC ? _self.designOutdoorTempC : designOutdoorTempC // ignore: cast_nullable_to_non_nullable
as double,defaultIndoorTempC: null == defaultIndoorTempC ? _self.defaultIndoorTempC : defaultIndoorTempC // ignore: cast_nullable_to_non_nullable
as double,floorHeightMm: null == floorHeightMm ? _self.floorHeightMm : floorHeightMm // ignore: cast_nullable_to_non_nullable
as int,unheatedSpaceTempC: null == unheatedSpaceTempC ? _self.unheatedSpaceTempC : unheatedSpaceTempC // ignore: cast_nullable_to_non_nullable
as double,defaultExteriorWallThicknessMm: null == defaultExteriorWallThicknessMm ? _self.defaultExteriorWallThicknessMm : defaultExteriorWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultInteriorWallThicknessMm: null == defaultInteriorWallThicknessMm ? _self.defaultInteriorWallThicknessMm : defaultInteriorWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultPartitionWallThicknessMm: null == defaultPartitionWallThicknessMm ? _self.defaultPartitionWallThicknessMm : defaultPartitionWallThicknessMm // ignore: cast_nullable_to_non_nullable
as int,defaultExteriorMaterialId: null == defaultExteriorMaterialId ? _self.defaultExteriorMaterialId : defaultExteriorMaterialId // ignore: cast_nullable_to_non_nullable
as String,defaultInteriorMaterialId: null == defaultInteriorMaterialId ? _self.defaultInteriorMaterialId : defaultInteriorMaterialId // ignore: cast_nullable_to_non_nullable
as String,defaultPartitionMaterialId: null == defaultPartitionMaterialId ? _self.defaultPartitionMaterialId : defaultPartitionMaterialId // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as GeoLocation?,
  ));
}

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $GeoLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}

// dart format on
