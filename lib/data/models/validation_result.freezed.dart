// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'validation_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ValidationResult {

/// Error, warning, or informational classification.
 WarningSeverity get severity;/// UUID of the element that triggered this result.
 String get elementId;/// Domain type of the element (e.g. "room", "circuit", "zone").
 String get elementType;/// Human-readable description of the issue.
 String get message;/// Optional remediation hint shown in the UI.
 String? get suggestedFix;
/// Create a copy of ValidationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidationResultCopyWith<ValidationResult> get copyWith => _$ValidationResultCopyWithImpl<ValidationResult>(this as ValidationResult, _$identity);

  /// Serializes this ValidationResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidationResult&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.elementId, elementId) || other.elementId == elementId)&&(identical(other.elementType, elementType) || other.elementType == elementType)&&(identical(other.message, message) || other.message == message)&&(identical(other.suggestedFix, suggestedFix) || other.suggestedFix == suggestedFix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,severity,elementId,elementType,message,suggestedFix);

@override
String toString() {
  return 'ValidationResult(severity: $severity, elementId: $elementId, elementType: $elementType, message: $message, suggestedFix: $suggestedFix)';
}


}

/// @nodoc
abstract mixin class $ValidationResultCopyWith<$Res>  {
  factory $ValidationResultCopyWith(ValidationResult value, $Res Function(ValidationResult) _then) = _$ValidationResultCopyWithImpl;
@useResult
$Res call({
 WarningSeverity severity, String elementId, String elementType, String message, String? suggestedFix
});




}
/// @nodoc
class _$ValidationResultCopyWithImpl<$Res>
    implements $ValidationResultCopyWith<$Res> {
  _$ValidationResultCopyWithImpl(this._self, this._then);

  final ValidationResult _self;
  final $Res Function(ValidationResult) _then;

/// Create a copy of ValidationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? severity = null,Object? elementId = null,Object? elementType = null,Object? message = null,Object? suggestedFix = freezed,}) {
  return _then(_self.copyWith(
severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as WarningSeverity,elementId: null == elementId ? _self.elementId : elementId // ignore: cast_nullable_to_non_nullable
as String,elementType: null == elementType ? _self.elementType : elementType // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,suggestedFix: freezed == suggestedFix ? _self.suggestedFix : suggestedFix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ValidationResult].
extension ValidationResultPatterns on ValidationResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidationResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidationResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidationResult value)  $default,){
final _that = this;
switch (_that) {
case _ValidationResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidationResult value)?  $default,){
final _that = this;
switch (_that) {
case _ValidationResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WarningSeverity severity,  String elementId,  String elementType,  String message,  String? suggestedFix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidationResult() when $default != null:
return $default(_that.severity,_that.elementId,_that.elementType,_that.message,_that.suggestedFix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WarningSeverity severity,  String elementId,  String elementType,  String message,  String? suggestedFix)  $default,) {final _that = this;
switch (_that) {
case _ValidationResult():
return $default(_that.severity,_that.elementId,_that.elementType,_that.message,_that.suggestedFix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WarningSeverity severity,  String elementId,  String elementType,  String message,  String? suggestedFix)?  $default,) {final _that = this;
switch (_that) {
case _ValidationResult() when $default != null:
return $default(_that.severity,_that.elementId,_that.elementType,_that.message,_that.suggestedFix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ValidationResult implements ValidationResult {
  const _ValidationResult({required this.severity, required this.elementId, required this.elementType, required this.message, this.suggestedFix});
  factory _ValidationResult.fromJson(Map<String, dynamic> json) => _$ValidationResultFromJson(json);

/// Error, warning, or informational classification.
@override final  WarningSeverity severity;
/// UUID of the element that triggered this result.
@override final  String elementId;
/// Domain type of the element (e.g. "room", "circuit", "zone").
@override final  String elementType;
/// Human-readable description of the issue.
@override final  String message;
/// Optional remediation hint shown in the UI.
@override final  String? suggestedFix;

/// Create a copy of ValidationResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidationResultCopyWith<_ValidationResult> get copyWith => __$ValidationResultCopyWithImpl<_ValidationResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ValidationResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidationResult&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.elementId, elementId) || other.elementId == elementId)&&(identical(other.elementType, elementType) || other.elementType == elementType)&&(identical(other.message, message) || other.message == message)&&(identical(other.suggestedFix, suggestedFix) || other.suggestedFix == suggestedFix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,severity,elementId,elementType,message,suggestedFix);

@override
String toString() {
  return 'ValidationResult(severity: $severity, elementId: $elementId, elementType: $elementType, message: $message, suggestedFix: $suggestedFix)';
}


}

/// @nodoc
abstract mixin class _$ValidationResultCopyWith<$Res> implements $ValidationResultCopyWith<$Res> {
  factory _$ValidationResultCopyWith(_ValidationResult value, $Res Function(_ValidationResult) _then) = __$ValidationResultCopyWithImpl;
@override @useResult
$Res call({
 WarningSeverity severity, String elementId, String elementType, String message, String? suggestedFix
});




}
/// @nodoc
class __$ValidationResultCopyWithImpl<$Res>
    implements _$ValidationResultCopyWith<$Res> {
  __$ValidationResultCopyWithImpl(this._self, this._then);

  final _ValidationResult _self;
  final $Res Function(_ValidationResult) _then;

/// Create a copy of ValidationResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? severity = null,Object? elementId = null,Object? elementType = null,Object? message = null,Object? suggestedFix = freezed,}) {
  return _then(_ValidationResult(
severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as WarningSeverity,elementId: null == elementId ? _self.elementId : elementId // ignore: cast_nullable_to_non_nullable
as String,elementType: null == elementType ? _self.elementType : elementType // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,suggestedFix: freezed == suggestedFix ? _self.suggestedFix : suggestedFix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
