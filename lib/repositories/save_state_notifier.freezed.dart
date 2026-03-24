// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'save_state_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SaveState {

/// `true` when in-database changes have not yet been written to the
/// `.hsp` export file.
 bool get isDirty;/// Timestamp of the most recent successful `.hsp` export.
/// `null` if the project has never been exported.
 DateTime? get lastExportedAt;/// Absolute file-system path of the most recent `.hsp` export.
/// `null` if the project has never been exported, or the path is
/// unknown.
 String? get lastExportPath;/// `true` while a background `.hsp` write is in progress.
 bool get isAutoExporting;
/// Create a copy of SaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaveStateCopyWith<SaveState> get copyWith => _$SaveStateCopyWithImpl<SaveState>(this as SaveState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaveState&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.lastExportedAt, lastExportedAt) || other.lastExportedAt == lastExportedAt)&&(identical(other.lastExportPath, lastExportPath) || other.lastExportPath == lastExportPath)&&(identical(other.isAutoExporting, isAutoExporting) || other.isAutoExporting == isAutoExporting));
}


@override
int get hashCode => Object.hash(runtimeType,isDirty,lastExportedAt,lastExportPath,isAutoExporting);

@override
String toString() {
  return 'SaveState(isDirty: $isDirty, lastExportedAt: $lastExportedAt, lastExportPath: $lastExportPath, isAutoExporting: $isAutoExporting)';
}


}

/// @nodoc
abstract mixin class $SaveStateCopyWith<$Res>  {
  factory $SaveStateCopyWith(SaveState value, $Res Function(SaveState) _then) = _$SaveStateCopyWithImpl;
@useResult
$Res call({
 bool isDirty, DateTime? lastExportedAt, String? lastExportPath, bool isAutoExporting
});




}
/// @nodoc
class _$SaveStateCopyWithImpl<$Res>
    implements $SaveStateCopyWith<$Res> {
  _$SaveStateCopyWithImpl(this._self, this._then);

  final SaveState _self;
  final $Res Function(SaveState) _then;

/// Create a copy of SaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isDirty = null,Object? lastExportedAt = freezed,Object? lastExportPath = freezed,Object? isAutoExporting = null,}) {
  return _then(_self.copyWith(
isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,lastExportedAt: freezed == lastExportedAt ? _self.lastExportedAt : lastExportedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastExportPath: freezed == lastExportPath ? _self.lastExportPath : lastExportPath // ignore: cast_nullable_to_non_nullable
as String?,isAutoExporting: null == isAutoExporting ? _self.isAutoExporting : isAutoExporting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SaveState].
extension SaveStatePatterns on SaveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaveState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaveState value)  $default,){
final _that = this;
switch (_that) {
case _SaveState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaveState value)?  $default,){
final _that = this;
switch (_that) {
case _SaveState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isDirty,  DateTime? lastExportedAt,  String? lastExportPath,  bool isAutoExporting)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaveState() when $default != null:
return $default(_that.isDirty,_that.lastExportedAt,_that.lastExportPath,_that.isAutoExporting);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isDirty,  DateTime? lastExportedAt,  String? lastExportPath,  bool isAutoExporting)  $default,) {final _that = this;
switch (_that) {
case _SaveState():
return $default(_that.isDirty,_that.lastExportedAt,_that.lastExportPath,_that.isAutoExporting);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isDirty,  DateTime? lastExportedAt,  String? lastExportPath,  bool isAutoExporting)?  $default,) {final _that = this;
switch (_that) {
case _SaveState() when $default != null:
return $default(_that.isDirty,_that.lastExportedAt,_that.lastExportPath,_that.isAutoExporting);case _:
  return null;

}
}

}

/// @nodoc


class _SaveState implements SaveState {
  const _SaveState({required this.isDirty, required this.lastExportedAt, required this.lastExportPath, required this.isAutoExporting});
  

/// `true` when in-database changes have not yet been written to the
/// `.hsp` export file.
@override final  bool isDirty;
/// Timestamp of the most recent successful `.hsp` export.
/// `null` if the project has never been exported.
@override final  DateTime? lastExportedAt;
/// Absolute file-system path of the most recent `.hsp` export.
/// `null` if the project has never been exported, or the path is
/// unknown.
@override final  String? lastExportPath;
/// `true` while a background `.hsp` write is in progress.
@override final  bool isAutoExporting;

/// Create a copy of SaveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaveStateCopyWith<_SaveState> get copyWith => __$SaveStateCopyWithImpl<_SaveState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaveState&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.lastExportedAt, lastExportedAt) || other.lastExportedAt == lastExportedAt)&&(identical(other.lastExportPath, lastExportPath) || other.lastExportPath == lastExportPath)&&(identical(other.isAutoExporting, isAutoExporting) || other.isAutoExporting == isAutoExporting));
}


@override
int get hashCode => Object.hash(runtimeType,isDirty,lastExportedAt,lastExportPath,isAutoExporting);

@override
String toString() {
  return 'SaveState(isDirty: $isDirty, lastExportedAt: $lastExportedAt, lastExportPath: $lastExportPath, isAutoExporting: $isAutoExporting)';
}


}

/// @nodoc
abstract mixin class _$SaveStateCopyWith<$Res> implements $SaveStateCopyWith<$Res> {
  factory _$SaveStateCopyWith(_SaveState value, $Res Function(_SaveState) _then) = __$SaveStateCopyWithImpl;
@override @useResult
$Res call({
 bool isDirty, DateTime? lastExportedAt, String? lastExportPath, bool isAutoExporting
});




}
/// @nodoc
class __$SaveStateCopyWithImpl<$Res>
    implements _$SaveStateCopyWith<$Res> {
  __$SaveStateCopyWithImpl(this._self, this._then);

  final _SaveState _self;
  final $Res Function(_SaveState) _then;

/// Create a copy of SaveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isDirty = null,Object? lastExportedAt = freezed,Object? lastExportPath = freezed,Object? isAutoExporting = null,}) {
  return _then(_SaveState(
isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,lastExportedAt: freezed == lastExportedAt ? _self.lastExportedAt : lastExportedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastExportPath: freezed == lastExportPath ? _self.lastExportPath : lastExportPath // ignore: cast_nullable_to_non_nullable
as String?,isAutoExporting: null == isAutoExporting ? _self.isAutoExporting : isAutoExporting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
