// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'context_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ContextState {

 String get greeting; String get contextDescription; bool get isLocationEnabled; bool get isNotificationsEnabled; DateTime? get lastUpdated;/// Human-readable address from reverse geocoding (e.g. "Soho, New York").
 String? get locationLabel;/// Motion state derived from GPS speed (e.g. "Stationary", "Walking").
 String get activityLabel;/// Optional weather summary (e.g. "21° Clear").
 String? get weather;/// Nearby venues fetched from Google Places — populated only when stationary.
 List<PlaceModel> get nearbyPlaces;
/// Create a copy of ContextState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContextStateCopyWith<ContextState> get copyWith => _$ContextStateCopyWithImpl<ContextState>(this as ContextState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContextState&&(identical(other.greeting, greeting) || other.greeting == greeting)&&(identical(other.contextDescription, contextDescription) || other.contextDescription == contextDescription)&&(identical(other.isLocationEnabled, isLocationEnabled) || other.isLocationEnabled == isLocationEnabled)&&(identical(other.isNotificationsEnabled, isNotificationsEnabled) || other.isNotificationsEnabled == isNotificationsEnabled)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.locationLabel, locationLabel) || other.locationLabel == locationLabel)&&(identical(other.activityLabel, activityLabel) || other.activityLabel == activityLabel)&&(identical(other.weather, weather) || other.weather == weather)&&const DeepCollectionEquality().equals(other.nearbyPlaces, nearbyPlaces));
}


@override
int get hashCode => Object.hash(runtimeType,greeting,contextDescription,isLocationEnabled,isNotificationsEnabled,lastUpdated,locationLabel,activityLabel,weather,const DeepCollectionEquality().hash(nearbyPlaces));

@override
String toString() {
  return 'ContextState(greeting: $greeting, contextDescription: $contextDescription, isLocationEnabled: $isLocationEnabled, isNotificationsEnabled: $isNotificationsEnabled, lastUpdated: $lastUpdated, locationLabel: $locationLabel, activityLabel: $activityLabel, weather: $weather, nearbyPlaces: $nearbyPlaces)';
}


}

/// @nodoc
abstract mixin class $ContextStateCopyWith<$Res>  {
  factory $ContextStateCopyWith(ContextState value, $Res Function(ContextState) _then) = _$ContextStateCopyWithImpl;
@useResult
$Res call({
 String greeting, String contextDescription, bool isLocationEnabled, bool isNotificationsEnabled, DateTime? lastUpdated, String? locationLabel, String activityLabel, String? weather, List<PlaceModel> nearbyPlaces
});




}
/// @nodoc
class _$ContextStateCopyWithImpl<$Res>
    implements $ContextStateCopyWith<$Res> {
  _$ContextStateCopyWithImpl(this._self, this._then);

  final ContextState _self;
  final $Res Function(ContextState) _then;

/// Create a copy of ContextState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? greeting = null,Object? contextDescription = null,Object? isLocationEnabled = null,Object? isNotificationsEnabled = null,Object? lastUpdated = freezed,Object? locationLabel = freezed,Object? activityLabel = null,Object? weather = freezed,Object? nearbyPlaces = null,}) {
  return _then(_self.copyWith(
greeting: null == greeting ? _self.greeting : greeting // ignore: cast_nullable_to_non_nullable
as String,contextDescription: null == contextDescription ? _self.contextDescription : contextDescription // ignore: cast_nullable_to_non_nullable
as String,isLocationEnabled: null == isLocationEnabled ? _self.isLocationEnabled : isLocationEnabled // ignore: cast_nullable_to_non_nullable
as bool,isNotificationsEnabled: null == isNotificationsEnabled ? _self.isNotificationsEnabled : isNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime?,locationLabel: freezed == locationLabel ? _self.locationLabel : locationLabel // ignore: cast_nullable_to_non_nullable
as String?,activityLabel: null == activityLabel ? _self.activityLabel : activityLabel // ignore: cast_nullable_to_non_nullable
as String,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as String?,nearbyPlaces: null == nearbyPlaces ? _self.nearbyPlaces : nearbyPlaces // ignore: cast_nullable_to_non_nullable
as List<PlaceModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [ContextState].
extension ContextStatePatterns on ContextState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContextState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContextState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContextState value)  $default,){
final _that = this;
switch (_that) {
case _ContextState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContextState value)?  $default,){
final _that = this;
switch (_that) {
case _ContextState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String greeting,  String contextDescription,  bool isLocationEnabled,  bool isNotificationsEnabled,  DateTime? lastUpdated,  String? locationLabel,  String activityLabel,  String? weather,  List<PlaceModel> nearbyPlaces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContextState() when $default != null:
return $default(_that.greeting,_that.contextDescription,_that.isLocationEnabled,_that.isNotificationsEnabled,_that.lastUpdated,_that.locationLabel,_that.activityLabel,_that.weather,_that.nearbyPlaces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String greeting,  String contextDescription,  bool isLocationEnabled,  bool isNotificationsEnabled,  DateTime? lastUpdated,  String? locationLabel,  String activityLabel,  String? weather,  List<PlaceModel> nearbyPlaces)  $default,) {final _that = this;
switch (_that) {
case _ContextState():
return $default(_that.greeting,_that.contextDescription,_that.isLocationEnabled,_that.isNotificationsEnabled,_that.lastUpdated,_that.locationLabel,_that.activityLabel,_that.weather,_that.nearbyPlaces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String greeting,  String contextDescription,  bool isLocationEnabled,  bool isNotificationsEnabled,  DateTime? lastUpdated,  String? locationLabel,  String activityLabel,  String? weather,  List<PlaceModel> nearbyPlaces)?  $default,) {final _that = this;
switch (_that) {
case _ContextState() when $default != null:
return $default(_that.greeting,_that.contextDescription,_that.isLocationEnabled,_that.isNotificationsEnabled,_that.lastUpdated,_that.locationLabel,_that.activityLabel,_that.weather,_that.nearbyPlaces);case _:
  return null;

}
}

}

/// @nodoc


class _ContextState extends ContextState {
  const _ContextState({required this.greeting, required this.contextDescription, this.isLocationEnabled = false, this.isNotificationsEnabled = false, this.lastUpdated, this.locationLabel, this.activityLabel = 'Stationary', this.weather, final  List<PlaceModel> nearbyPlaces = const <PlaceModel>[]}): _nearbyPlaces = nearbyPlaces,super._();
  

@override final  String greeting;
@override final  String contextDescription;
@override@JsonKey() final  bool isLocationEnabled;
@override@JsonKey() final  bool isNotificationsEnabled;
@override final  DateTime? lastUpdated;
/// Human-readable address from reverse geocoding (e.g. "Soho, New York").
@override final  String? locationLabel;
/// Motion state derived from GPS speed (e.g. "Stationary", "Walking").
@override@JsonKey() final  String activityLabel;
/// Optional weather summary (e.g. "21° Clear").
@override final  String? weather;
/// Nearby venues fetched from Google Places — populated only when stationary.
 final  List<PlaceModel> _nearbyPlaces;
/// Nearby venues fetched from Google Places — populated only when stationary.
@override@JsonKey() List<PlaceModel> get nearbyPlaces {
  if (_nearbyPlaces is EqualUnmodifiableListView) return _nearbyPlaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nearbyPlaces);
}


/// Create a copy of ContextState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContextStateCopyWith<_ContextState> get copyWith => __$ContextStateCopyWithImpl<_ContextState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContextState&&(identical(other.greeting, greeting) || other.greeting == greeting)&&(identical(other.contextDescription, contextDescription) || other.contextDescription == contextDescription)&&(identical(other.isLocationEnabled, isLocationEnabled) || other.isLocationEnabled == isLocationEnabled)&&(identical(other.isNotificationsEnabled, isNotificationsEnabled) || other.isNotificationsEnabled == isNotificationsEnabled)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.locationLabel, locationLabel) || other.locationLabel == locationLabel)&&(identical(other.activityLabel, activityLabel) || other.activityLabel == activityLabel)&&(identical(other.weather, weather) || other.weather == weather)&&const DeepCollectionEquality().equals(other._nearbyPlaces, _nearbyPlaces));
}


@override
int get hashCode => Object.hash(runtimeType,greeting,contextDescription,isLocationEnabled,isNotificationsEnabled,lastUpdated,locationLabel,activityLabel,weather,const DeepCollectionEquality().hash(_nearbyPlaces));

@override
String toString() {
  return 'ContextState(greeting: $greeting, contextDescription: $contextDescription, isLocationEnabled: $isLocationEnabled, isNotificationsEnabled: $isNotificationsEnabled, lastUpdated: $lastUpdated, locationLabel: $locationLabel, activityLabel: $activityLabel, weather: $weather, nearbyPlaces: $nearbyPlaces)';
}


}

/// @nodoc
abstract mixin class _$ContextStateCopyWith<$Res> implements $ContextStateCopyWith<$Res> {
  factory _$ContextStateCopyWith(_ContextState value, $Res Function(_ContextState) _then) = __$ContextStateCopyWithImpl;
@override @useResult
$Res call({
 String greeting, String contextDescription, bool isLocationEnabled, bool isNotificationsEnabled, DateTime? lastUpdated, String? locationLabel, String activityLabel, String? weather, List<PlaceModel> nearbyPlaces
});




}
/// @nodoc
class __$ContextStateCopyWithImpl<$Res>
    implements _$ContextStateCopyWith<$Res> {
  __$ContextStateCopyWithImpl(this._self, this._then);

  final _ContextState _self;
  final $Res Function(_ContextState) _then;

/// Create a copy of ContextState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? greeting = null,Object? contextDescription = null,Object? isLocationEnabled = null,Object? isNotificationsEnabled = null,Object? lastUpdated = freezed,Object? locationLabel = freezed,Object? activityLabel = null,Object? weather = freezed,Object? nearbyPlaces = null,}) {
  return _then(_ContextState(
greeting: null == greeting ? _self.greeting : greeting // ignore: cast_nullable_to_non_nullable
as String,contextDescription: null == contextDescription ? _self.contextDescription : contextDescription // ignore: cast_nullable_to_non_nullable
as String,isLocationEnabled: null == isLocationEnabled ? _self.isLocationEnabled : isLocationEnabled // ignore: cast_nullable_to_non_nullable
as bool,isNotificationsEnabled: null == isNotificationsEnabled ? _self.isNotificationsEnabled : isNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime?,locationLabel: freezed == locationLabel ? _self.locationLabel : locationLabel // ignore: cast_nullable_to_non_nullable
as String?,activityLabel: null == activityLabel ? _self.activityLabel : activityLabel // ignore: cast_nullable_to_non_nullable
as String,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as String?,nearbyPlaces: null == nearbyPlaces ? _self._nearbyPlaces : nearbyPlaces // ignore: cast_nullable_to_non_nullable
as List<PlaceModel>,
  ));
}


}

// dart format on
