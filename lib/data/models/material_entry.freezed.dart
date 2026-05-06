// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'material_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MaterialEntry {

/// UUID v4 primary key.
 String get id;/// Canonical English display name (1–200 chars).
 String get name;/// Optional German display name. Falls back to [name] when absent.
 String? get nameDe;/// Material category string (e.g. "Masonry", "Insulation boards").
 String get category;/// Material subcategory string (e.g. "Historic brick", "Stone wool board").
 String get subcategory;/// Default thermal conductivity λ in W/(m·K).
 double get lambdaDefault;/// Default bulk density in kg/m³.
 double get densityDefault;/// Default specific heat capacity in J/(kg·K).
 double get specificHeatDefault;/// True for seed/built-in materials that ship with the application.
 bool get isBuiltIn;
/// Create a copy of MaterialEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MaterialEntryCopyWith<MaterialEntry> get copyWith => _$MaterialEntryCopyWithImpl<MaterialEntry>(this as MaterialEntry, _$identity);

  /// Serializes this MaterialEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MaterialEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameDe, nameDe) || other.nameDe == nameDe)&&(identical(other.category, category) || other.category == category)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.lambdaDefault, lambdaDefault) || other.lambdaDefault == lambdaDefault)&&(identical(other.densityDefault, densityDefault) || other.densityDefault == densityDefault)&&(identical(other.specificHeatDefault, specificHeatDefault) || other.specificHeatDefault == specificHeatDefault)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameDe,category,subcategory,lambdaDefault,densityDefault,specificHeatDefault,isBuiltIn);

@override
String toString() {
  return 'MaterialEntry(id: $id, name: $name, nameDe: $nameDe, category: $category, subcategory: $subcategory, lambdaDefault: $lambdaDefault, densityDefault: $densityDefault, specificHeatDefault: $specificHeatDefault, isBuiltIn: $isBuiltIn)';
}


}

/// @nodoc
abstract mixin class $MaterialEntryCopyWith<$Res>  {
  factory $MaterialEntryCopyWith(MaterialEntry value, $Res Function(MaterialEntry) _then) = _$MaterialEntryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? nameDe, String category, String subcategory, double lambdaDefault, double densityDefault, double specificHeatDefault, bool isBuiltIn
});




}
/// @nodoc
class _$MaterialEntryCopyWithImpl<$Res>
    implements $MaterialEntryCopyWith<$Res> {
  _$MaterialEntryCopyWithImpl(this._self, this._then);

  final MaterialEntry _self;
  final $Res Function(MaterialEntry) _then;

/// Create a copy of MaterialEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nameDe = freezed,Object? category = null,Object? subcategory = null,Object? lambdaDefault = null,Object? densityDefault = null,Object? specificHeatDefault = null,Object? isBuiltIn = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameDe: freezed == nameDe ? _self.nameDe : nameDe // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,subcategory: null == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String,lambdaDefault: null == lambdaDefault ? _self.lambdaDefault : lambdaDefault // ignore: cast_nullable_to_non_nullable
as double,densityDefault: null == densityDefault ? _self.densityDefault : densityDefault // ignore: cast_nullable_to_non_nullable
as double,specificHeatDefault: null == specificHeatDefault ? _self.specificHeatDefault : specificHeatDefault // ignore: cast_nullable_to_non_nullable
as double,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MaterialEntry].
extension MaterialEntryPatterns on MaterialEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MaterialEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MaterialEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MaterialEntry value)  $default,){
final _that = this;
switch (_that) {
case _MaterialEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MaterialEntry value)?  $default,){
final _that = this;
switch (_that) {
case _MaterialEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? nameDe,  String category,  String subcategory,  double lambdaDefault,  double densityDefault,  double specificHeatDefault,  bool isBuiltIn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MaterialEntry() when $default != null:
return $default(_that.id,_that.name,_that.nameDe,_that.category,_that.subcategory,_that.lambdaDefault,_that.densityDefault,_that.specificHeatDefault,_that.isBuiltIn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? nameDe,  String category,  String subcategory,  double lambdaDefault,  double densityDefault,  double specificHeatDefault,  bool isBuiltIn)  $default,) {final _that = this;
switch (_that) {
case _MaterialEntry():
return $default(_that.id,_that.name,_that.nameDe,_that.category,_that.subcategory,_that.lambdaDefault,_that.densityDefault,_that.specificHeatDefault,_that.isBuiltIn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? nameDe,  String category,  String subcategory,  double lambdaDefault,  double densityDefault,  double specificHeatDefault,  bool isBuiltIn)?  $default,) {final _that = this;
switch (_that) {
case _MaterialEntry() when $default != null:
return $default(_that.id,_that.name,_that.nameDe,_that.category,_that.subcategory,_that.lambdaDefault,_that.densityDefault,_that.specificHeatDefault,_that.isBuiltIn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MaterialEntry implements MaterialEntry {
  const _MaterialEntry({required this.id, required this.name, this.nameDe, required this.category, this.subcategory = '', required this.lambdaDefault, required this.densityDefault, required this.specificHeatDefault, this.isBuiltIn = true});
  factory _MaterialEntry.fromJson(Map<String, dynamic> json) => _$MaterialEntryFromJson(json);

/// UUID v4 primary key.
@override final  String id;
/// Canonical English display name (1–200 chars).
@override final  String name;
/// Optional German display name. Falls back to [name] when absent.
@override final  String? nameDe;
/// Material category string (e.g. "Masonry", "Insulation boards").
@override final  String category;
/// Material subcategory string (e.g. "Historic brick", "Stone wool board").
@override@JsonKey() final  String subcategory;
/// Default thermal conductivity λ in W/(m·K).
@override final  double lambdaDefault;
/// Default bulk density in kg/m³.
@override final  double densityDefault;
/// Default specific heat capacity in J/(kg·K).
@override final  double specificHeatDefault;
/// True for seed/built-in materials that ship with the application.
@override@JsonKey() final  bool isBuiltIn;

/// Create a copy of MaterialEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MaterialEntryCopyWith<_MaterialEntry> get copyWith => __$MaterialEntryCopyWithImpl<_MaterialEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MaterialEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MaterialEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameDe, nameDe) || other.nameDe == nameDe)&&(identical(other.category, category) || other.category == category)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.lambdaDefault, lambdaDefault) || other.lambdaDefault == lambdaDefault)&&(identical(other.densityDefault, densityDefault) || other.densityDefault == densityDefault)&&(identical(other.specificHeatDefault, specificHeatDefault) || other.specificHeatDefault == specificHeatDefault)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameDe,category,subcategory,lambdaDefault,densityDefault,specificHeatDefault,isBuiltIn);

@override
String toString() {
  return 'MaterialEntry(id: $id, name: $name, nameDe: $nameDe, category: $category, subcategory: $subcategory, lambdaDefault: $lambdaDefault, densityDefault: $densityDefault, specificHeatDefault: $specificHeatDefault, isBuiltIn: $isBuiltIn)';
}


}

/// @nodoc
abstract mixin class _$MaterialEntryCopyWith<$Res> implements $MaterialEntryCopyWith<$Res> {
  factory _$MaterialEntryCopyWith(_MaterialEntry value, $Res Function(_MaterialEntry) _then) = __$MaterialEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? nameDe, String category, String subcategory, double lambdaDefault, double densityDefault, double specificHeatDefault, bool isBuiltIn
});




}
/// @nodoc
class __$MaterialEntryCopyWithImpl<$Res>
    implements _$MaterialEntryCopyWith<$Res> {
  __$MaterialEntryCopyWithImpl(this._self, this._then);

  final _MaterialEntry _self;
  final $Res Function(_MaterialEntry) _then;

/// Create a copy of MaterialEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nameDe = freezed,Object? category = null,Object? subcategory = null,Object? lambdaDefault = null,Object? densityDefault = null,Object? specificHeatDefault = null,Object? isBuiltIn = null,}) {
  return _then(_MaterialEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameDe: freezed == nameDe ? _self.nameDe : nameDe // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,subcategory: null == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String,lambdaDefault: null == lambdaDefault ? _self.lambdaDefault : lambdaDefault // ignore: cast_nullable_to_non_nullable
as double,densityDefault: null == densityDefault ? _self.densityDefault : densityDefault // ignore: cast_nullable_to_non_nullable
as double,specificHeatDefault: null == specificHeatDefault ? _self.specificHeatDefault : specificHeatDefault // ignore: cast_nullable_to_non_nullable
as double,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
