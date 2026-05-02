// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'persona_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PersonaTrait {

 String get label; double get confidence;
/// Create a copy of PersonaTrait
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersonaTraitCopyWith<PersonaTrait> get copyWith => _$PersonaTraitCopyWithImpl<PersonaTrait>(this as PersonaTrait, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersonaTrait&&(identical(other.label, label) || other.label == label)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}


@override
int get hashCode => Object.hash(runtimeType,label,confidence);

@override
String toString() {
  return 'PersonaTrait(label: $label, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $PersonaTraitCopyWith<$Res>  {
  factory $PersonaTraitCopyWith(PersonaTrait value, $Res Function(PersonaTrait) _then) = _$PersonaTraitCopyWithImpl;
@useResult
$Res call({
 String label, double confidence
});




}
/// @nodoc
class _$PersonaTraitCopyWithImpl<$Res>
    implements $PersonaTraitCopyWith<$Res> {
  _$PersonaTraitCopyWithImpl(this._self, this._then);

  final PersonaTrait _self;
  final $Res Function(PersonaTrait) _then;

/// Create a copy of PersonaTrait
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? confidence = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PersonaTrait].
extension PersonaTraitPatterns on PersonaTrait {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PersonaTrait value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PersonaTrait() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PersonaTrait value)  $default,){
final _that = this;
switch (_that) {
case _PersonaTrait():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PersonaTrait value)?  $default,){
final _that = this;
switch (_that) {
case _PersonaTrait() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  double confidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PersonaTrait() when $default != null:
return $default(_that.label,_that.confidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  double confidence)  $default,) {final _that = this;
switch (_that) {
case _PersonaTrait():
return $default(_that.label,_that.confidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  double confidence)?  $default,) {final _that = this;
switch (_that) {
case _PersonaTrait() when $default != null:
return $default(_that.label,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc


class _PersonaTrait extends PersonaTrait {
  const _PersonaTrait({required this.label, required this.confidence}): super._();
  

@override final  String label;
@override final  double confidence;

/// Create a copy of PersonaTrait
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PersonaTraitCopyWith<_PersonaTrait> get copyWith => __$PersonaTraitCopyWithImpl<_PersonaTrait>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PersonaTrait&&(identical(other.label, label) || other.label == label)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}


@override
int get hashCode => Object.hash(runtimeType,label,confidence);

@override
String toString() {
  return 'PersonaTrait(label: $label, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$PersonaTraitCopyWith<$Res> implements $PersonaTraitCopyWith<$Res> {
  factory _$PersonaTraitCopyWith(_PersonaTrait value, $Res Function(_PersonaTrait) _then) = __$PersonaTraitCopyWithImpl;
@override @useResult
$Res call({
 String label, double confidence
});




}
/// @nodoc
class __$PersonaTraitCopyWithImpl<$Res>
    implements _$PersonaTraitCopyWith<$Res> {
  __$PersonaTraitCopyWithImpl(this._self, this._then);

  final _PersonaTrait _self;
  final $Res Function(_PersonaTrait) _then;

/// Create a copy of PersonaTrait
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? confidence = null,}) {
  return _then(_PersonaTrait(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$PersonaModel {

 List<PersonaTrait> get traits; Map<String, double> get preferences; DateTime get lastUpdated; int get signalsProcessedToday;
/// Create a copy of PersonaModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersonaModelCopyWith<PersonaModel> get copyWith => _$PersonaModelCopyWithImpl<PersonaModel>(this as PersonaModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersonaModel&&const DeepCollectionEquality().equals(other.traits, traits)&&const DeepCollectionEquality().equals(other.preferences, preferences)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.signalsProcessedToday, signalsProcessedToday) || other.signalsProcessedToday == signalsProcessedToday));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(traits),const DeepCollectionEquality().hash(preferences),lastUpdated,signalsProcessedToday);

@override
String toString() {
  return 'PersonaModel(traits: $traits, preferences: $preferences, lastUpdated: $lastUpdated, signalsProcessedToday: $signalsProcessedToday)';
}


}

/// @nodoc
abstract mixin class $PersonaModelCopyWith<$Res>  {
  factory $PersonaModelCopyWith(PersonaModel value, $Res Function(PersonaModel) _then) = _$PersonaModelCopyWithImpl;
@useResult
$Res call({
 List<PersonaTrait> traits, Map<String, double> preferences, DateTime lastUpdated, int signalsProcessedToday
});




}
/// @nodoc
class _$PersonaModelCopyWithImpl<$Res>
    implements $PersonaModelCopyWith<$Res> {
  _$PersonaModelCopyWithImpl(this._self, this._then);

  final PersonaModel _self;
  final $Res Function(PersonaModel) _then;

/// Create a copy of PersonaModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? traits = null,Object? preferences = null,Object? lastUpdated = null,Object? signalsProcessedToday = null,}) {
  return _then(_self.copyWith(
traits: null == traits ? _self.traits : traits // ignore: cast_nullable_to_non_nullable
as List<PersonaTrait>,preferences: null == preferences ? _self.preferences : preferences // ignore: cast_nullable_to_non_nullable
as Map<String, double>,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,signalsProcessedToday: null == signalsProcessedToday ? _self.signalsProcessedToday : signalsProcessedToday // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PersonaModel].
extension PersonaModelPatterns on PersonaModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PersonaModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PersonaModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PersonaModel value)  $default,){
final _that = this;
switch (_that) {
case _PersonaModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PersonaModel value)?  $default,){
final _that = this;
switch (_that) {
case _PersonaModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PersonaTrait> traits,  Map<String, double> preferences,  DateTime lastUpdated,  int signalsProcessedToday)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PersonaModel() when $default != null:
return $default(_that.traits,_that.preferences,_that.lastUpdated,_that.signalsProcessedToday);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PersonaTrait> traits,  Map<String, double> preferences,  DateTime lastUpdated,  int signalsProcessedToday)  $default,) {final _that = this;
switch (_that) {
case _PersonaModel():
return $default(_that.traits,_that.preferences,_that.lastUpdated,_that.signalsProcessedToday);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PersonaTrait> traits,  Map<String, double> preferences,  DateTime lastUpdated,  int signalsProcessedToday)?  $default,) {final _that = this;
switch (_that) {
case _PersonaModel() when $default != null:
return $default(_that.traits,_that.preferences,_that.lastUpdated,_that.signalsProcessedToday);case _:
  return null;

}
}

}

/// @nodoc


class _PersonaModel extends PersonaModel {
  const _PersonaModel({required final  List<PersonaTrait> traits, required final  Map<String, double> preferences, required this.lastUpdated, this.signalsProcessedToday = 0}): _traits = traits,_preferences = preferences,super._();
  

 final  List<PersonaTrait> _traits;
@override List<PersonaTrait> get traits {
  if (_traits is EqualUnmodifiableListView) return _traits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_traits);
}

 final  Map<String, double> _preferences;
@override Map<String, double> get preferences {
  if (_preferences is EqualUnmodifiableMapView) return _preferences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_preferences);
}

@override final  DateTime lastUpdated;
@override@JsonKey() final  int signalsProcessedToday;

/// Create a copy of PersonaModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PersonaModelCopyWith<_PersonaModel> get copyWith => __$PersonaModelCopyWithImpl<_PersonaModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PersonaModel&&const DeepCollectionEquality().equals(other._traits, _traits)&&const DeepCollectionEquality().equals(other._preferences, _preferences)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.signalsProcessedToday, signalsProcessedToday) || other.signalsProcessedToday == signalsProcessedToday));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_traits),const DeepCollectionEquality().hash(_preferences),lastUpdated,signalsProcessedToday);

@override
String toString() {
  return 'PersonaModel(traits: $traits, preferences: $preferences, lastUpdated: $lastUpdated, signalsProcessedToday: $signalsProcessedToday)';
}


}

/// @nodoc
abstract mixin class _$PersonaModelCopyWith<$Res> implements $PersonaModelCopyWith<$Res> {
  factory _$PersonaModelCopyWith(_PersonaModel value, $Res Function(_PersonaModel) _then) = __$PersonaModelCopyWithImpl;
@override @useResult
$Res call({
 List<PersonaTrait> traits, Map<String, double> preferences, DateTime lastUpdated, int signalsProcessedToday
});




}
/// @nodoc
class __$PersonaModelCopyWithImpl<$Res>
    implements _$PersonaModelCopyWith<$Res> {
  __$PersonaModelCopyWithImpl(this._self, this._then);

  final _PersonaModel _self;
  final $Res Function(_PersonaModel) _then;

/// Create a copy of PersonaModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? traits = null,Object? preferences = null,Object? lastUpdated = null,Object? signalsProcessedToday = null,}) {
  return _then(_PersonaModel(
traits: null == traits ? _self._traits : traits // ignore: cast_nullable_to_non_nullable
as List<PersonaTrait>,preferences: null == preferences ? _self._preferences : preferences // ignore: cast_nullable_to_non_nullable
as Map<String, double>,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,signalsProcessedToday: null == signalsProcessedToday ? _self.signalsProcessedToday : signalsProcessedToday // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
