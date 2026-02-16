// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'material_layer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MaterialLayer {

/// UUID v4 primary key.
 String get id;/// UUID of the parent [WallConstruction].
 String get constructionId;/// Position in the layer stack (0 = outermost). Must be ≥ 0.
 int get sortOrder;/// UUID of the [MaterialEntry] this layer is based on.
 String get materialId;/// Layer thickness in millimetres. Range: 1.0–1000.0.
 double get thicknessMm;/// Thermal conductivity λ in W/(m·K). Range: 0.01–50.0.
 double get thermalConductivity;/// Bulk density in kg/m³. Range: 1–10 000.
 double get density;/// Specific heat capacity in J/(kg·K). Range: 100–5000.
 double get specificHeat;
/// Create a copy of MaterialLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MaterialLayerCopyWith<MaterialLayer> get copyWith => _$MaterialLayerCopyWithImpl<MaterialLayer>(this as MaterialLayer, _$identity);

  /// Serializes this MaterialLayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MaterialLayer&&(identical(other.id, id) || other.id == id)&&(identical(other.constructionId, constructionId) || other.constructionId == constructionId)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.materialId, materialId) || other.materialId == materialId)&&(identical(other.thicknessMm, thicknessMm) || other.thicknessMm == thicknessMm)&&(identical(other.thermalConductivity, thermalConductivity) || other.thermalConductivity == thermalConductivity)&&(identical(other.density, density) || other.density == density)&&(identical(other.specificHeat, specificHeat) || other.specificHeat == specificHeat));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,constructionId,sortOrder,materialId,thicknessMm,thermalConductivity,density,specificHeat);

@override
String toString() {
  return 'MaterialLayer(id: $id, constructionId: $constructionId, sortOrder: $sortOrder, materialId: $materialId, thicknessMm: $thicknessMm, thermalConductivity: $thermalConductivity, density: $density, specificHeat: $specificHeat)';
}


}

/// @nodoc
abstract mixin class $MaterialLayerCopyWith<$Res>  {
  factory $MaterialLayerCopyWith(MaterialLayer value, $Res Function(MaterialLayer) _then) = _$MaterialLayerCopyWithImpl;
@useResult
$Res call({
 String id, String constructionId, int sortOrder, String materialId, double thicknessMm, double thermalConductivity, double density, double specificHeat
});




}
/// @nodoc
class _$MaterialLayerCopyWithImpl<$Res>
    implements $MaterialLayerCopyWith<$Res> {
  _$MaterialLayerCopyWithImpl(this._self, this._then);

  final MaterialLayer _self;
  final $Res Function(MaterialLayer) _then;

/// Create a copy of MaterialLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? constructionId = null,Object? sortOrder = null,Object? materialId = null,Object? thicknessMm = null,Object? thermalConductivity = null,Object? density = null,Object? specificHeat = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,constructionId: null == constructionId ? _self.constructionId : constructionId // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,materialId: null == materialId ? _self.materialId : materialId // ignore: cast_nullable_to_non_nullable
as String,thicknessMm: null == thicknessMm ? _self.thicknessMm : thicknessMm // ignore: cast_nullable_to_non_nullable
as double,thermalConductivity: null == thermalConductivity ? _self.thermalConductivity : thermalConductivity // ignore: cast_nullable_to_non_nullable
as double,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as double,specificHeat: null == specificHeat ? _self.specificHeat : specificHeat // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MaterialLayer].
extension MaterialLayerPatterns on MaterialLayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MaterialLayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MaterialLayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MaterialLayer value)  $default,){
final _that = this;
switch (_that) {
case _MaterialLayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MaterialLayer value)?  $default,){
final _that = this;
switch (_that) {
case _MaterialLayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String constructionId,  int sortOrder,  String materialId,  double thicknessMm,  double thermalConductivity,  double density,  double specificHeat)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MaterialLayer() when $default != null:
return $default(_that.id,_that.constructionId,_that.sortOrder,_that.materialId,_that.thicknessMm,_that.thermalConductivity,_that.density,_that.specificHeat);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String constructionId,  int sortOrder,  String materialId,  double thicknessMm,  double thermalConductivity,  double density,  double specificHeat)  $default,) {final _that = this;
switch (_that) {
case _MaterialLayer():
return $default(_that.id,_that.constructionId,_that.sortOrder,_that.materialId,_that.thicknessMm,_that.thermalConductivity,_that.density,_that.specificHeat);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String constructionId,  int sortOrder,  String materialId,  double thicknessMm,  double thermalConductivity,  double density,  double specificHeat)?  $default,) {final _that = this;
switch (_that) {
case _MaterialLayer() when $default != null:
return $default(_that.id,_that.constructionId,_that.sortOrder,_that.materialId,_that.thicknessMm,_that.thermalConductivity,_that.density,_that.specificHeat);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MaterialLayer implements MaterialLayer {
  const _MaterialLayer({required this.id, required this.constructionId, required this.sortOrder, required this.materialId, required this.thicknessMm, required this.thermalConductivity, required this.density, required this.specificHeat});
  factory _MaterialLayer.fromJson(Map<String, dynamic> json) => _$MaterialLayerFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// UUID of the parent [WallConstruction].
@override final  String constructionId;
/// Position in the layer stack (0 = outermost). Must be ≥ 0.
@override final  int sortOrder;
/// UUID of the [MaterialEntry] this layer is based on.
@override final  String materialId;
/// Layer thickness in millimetres. Range: 1.0–1000.0.
@override final  double thicknessMm;
/// Thermal conductivity λ in W/(m·K). Range: 0.01–50.0.
@override final  double thermalConductivity;
/// Bulk density in kg/m³. Range: 1–10 000.
@override final  double density;
/// Specific heat capacity in J/(kg·K). Range: 100–5000.
@override final  double specificHeat;

/// Create a copy of MaterialLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MaterialLayerCopyWith<_MaterialLayer> get copyWith => __$MaterialLayerCopyWithImpl<_MaterialLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MaterialLayerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MaterialLayer&&(identical(other.id, id) || other.id == id)&&(identical(other.constructionId, constructionId) || other.constructionId == constructionId)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.materialId, materialId) || other.materialId == materialId)&&(identical(other.thicknessMm, thicknessMm) || other.thicknessMm == thicknessMm)&&(identical(other.thermalConductivity, thermalConductivity) || other.thermalConductivity == thermalConductivity)&&(identical(other.density, density) || other.density == density)&&(identical(other.specificHeat, specificHeat) || other.specificHeat == specificHeat));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,constructionId,sortOrder,materialId,thicknessMm,thermalConductivity,density,specificHeat);

@override
String toString() {
  return 'MaterialLayer(id: $id, constructionId: $constructionId, sortOrder: $sortOrder, materialId: $materialId, thicknessMm: $thicknessMm, thermalConductivity: $thermalConductivity, density: $density, specificHeat: $specificHeat)';
}


}

/// @nodoc
abstract mixin class _$MaterialLayerCopyWith<$Res> implements $MaterialLayerCopyWith<$Res> {
  factory _$MaterialLayerCopyWith(_MaterialLayer value, $Res Function(_MaterialLayer) _then) = __$MaterialLayerCopyWithImpl;
@override @useResult
$Res call({
 String id, String constructionId, int sortOrder, String materialId, double thicknessMm, double thermalConductivity, double density, double specificHeat
});




}
/// @nodoc
class __$MaterialLayerCopyWithImpl<$Res>
    implements _$MaterialLayerCopyWith<$Res> {
  __$MaterialLayerCopyWithImpl(this._self, this._then);

  final _MaterialLayer _self;
  final $Res Function(_MaterialLayer) _then;

/// Create a copy of MaterialLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? constructionId = null,Object? sortOrder = null,Object? materialId = null,Object? thicknessMm = null,Object? thermalConductivity = null,Object? density = null,Object? specificHeat = null,}) {
  return _then(_MaterialLayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,constructionId: null == constructionId ? _self.constructionId : constructionId // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,materialId: null == materialId ? _self.materialId : materialId // ignore: cast_nullable_to_non_nullable
as String,thicknessMm: null == thicknessMm ? _self.thicknessMm : thicknessMm // ignore: cast_nullable_to_non_nullable
as double,thermalConductivity: null == thermalConductivity ? _self.thermalConductivity : thermalConductivity // ignore: cast_nullable_to_non_nullable
as double,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as double,specificHeat: null == specificHeat ? _self.specificHeat : specificHeat // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
