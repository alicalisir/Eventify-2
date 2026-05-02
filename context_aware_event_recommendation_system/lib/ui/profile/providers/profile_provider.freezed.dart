// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileSettings {

 bool get locationTrackingEnabled; bool get activityRecognitionEnabled; bool get notificationsEnabled; bool get trackingPaused;
/// Create a copy of ProfileSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSettingsCopyWith<ProfileSettings> get copyWith => _$ProfileSettingsCopyWithImpl<ProfileSettings>(this as ProfileSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSettings&&(identical(other.locationTrackingEnabled, locationTrackingEnabled) || other.locationTrackingEnabled == locationTrackingEnabled)&&(identical(other.activityRecognitionEnabled, activityRecognitionEnabled) || other.activityRecognitionEnabled == activityRecognitionEnabled)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled)&&(identical(other.trackingPaused, trackingPaused) || other.trackingPaused == trackingPaused));
}


@override
int get hashCode => Object.hash(runtimeType,locationTrackingEnabled,activityRecognitionEnabled,notificationsEnabled,trackingPaused);

@override
String toString() {
  return 'ProfileSettings(locationTrackingEnabled: $locationTrackingEnabled, activityRecognitionEnabled: $activityRecognitionEnabled, notificationsEnabled: $notificationsEnabled, trackingPaused: $trackingPaused)';
}


}

/// @nodoc
abstract mixin class $ProfileSettingsCopyWith<$Res>  {
  factory $ProfileSettingsCopyWith(ProfileSettings value, $Res Function(ProfileSettings) _then) = _$ProfileSettingsCopyWithImpl;
@useResult
$Res call({
 bool locationTrackingEnabled, bool activityRecognitionEnabled, bool notificationsEnabled, bool trackingPaused
});




}
/// @nodoc
class _$ProfileSettingsCopyWithImpl<$Res>
    implements $ProfileSettingsCopyWith<$Res> {
  _$ProfileSettingsCopyWithImpl(this._self, this._then);

  final ProfileSettings _self;
  final $Res Function(ProfileSettings) _then;

/// Create a copy of ProfileSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationTrackingEnabled = null,Object? activityRecognitionEnabled = null,Object? notificationsEnabled = null,Object? trackingPaused = null,}) {
  return _then(_self.copyWith(
locationTrackingEnabled: null == locationTrackingEnabled ? _self.locationTrackingEnabled : locationTrackingEnabled // ignore: cast_nullable_to_non_nullable
as bool,activityRecognitionEnabled: null == activityRecognitionEnabled ? _self.activityRecognitionEnabled : activityRecognitionEnabled // ignore: cast_nullable_to_non_nullable
as bool,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,trackingPaused: null == trackingPaused ? _self.trackingPaused : trackingPaused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileSettings].
extension ProfileSettingsPatterns on ProfileSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSettings value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool locationTrackingEnabled,  bool activityRecognitionEnabled,  bool notificationsEnabled,  bool trackingPaused)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileSettings() when $default != null:
return $default(_that.locationTrackingEnabled,_that.activityRecognitionEnabled,_that.notificationsEnabled,_that.trackingPaused);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool locationTrackingEnabled,  bool activityRecognitionEnabled,  bool notificationsEnabled,  bool trackingPaused)  $default,) {final _that = this;
switch (_that) {
case _ProfileSettings():
return $default(_that.locationTrackingEnabled,_that.activityRecognitionEnabled,_that.notificationsEnabled,_that.trackingPaused);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool locationTrackingEnabled,  bool activityRecognitionEnabled,  bool notificationsEnabled,  bool trackingPaused)?  $default,) {final _that = this;
switch (_that) {
case _ProfileSettings() when $default != null:
return $default(_that.locationTrackingEnabled,_that.activityRecognitionEnabled,_that.notificationsEnabled,_that.trackingPaused);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileSettings implements ProfileSettings {
  const _ProfileSettings({this.locationTrackingEnabled = true, this.activityRecognitionEnabled = true, this.notificationsEnabled = true, this.trackingPaused = false});
  

@override@JsonKey() final  bool locationTrackingEnabled;
@override@JsonKey() final  bool activityRecognitionEnabled;
@override@JsonKey() final  bool notificationsEnabled;
@override@JsonKey() final  bool trackingPaused;

/// Create a copy of ProfileSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSettingsCopyWith<_ProfileSettings> get copyWith => __$ProfileSettingsCopyWithImpl<_ProfileSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSettings&&(identical(other.locationTrackingEnabled, locationTrackingEnabled) || other.locationTrackingEnabled == locationTrackingEnabled)&&(identical(other.activityRecognitionEnabled, activityRecognitionEnabled) || other.activityRecognitionEnabled == activityRecognitionEnabled)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled)&&(identical(other.trackingPaused, trackingPaused) || other.trackingPaused == trackingPaused));
}


@override
int get hashCode => Object.hash(runtimeType,locationTrackingEnabled,activityRecognitionEnabled,notificationsEnabled,trackingPaused);

@override
String toString() {
  return 'ProfileSettings(locationTrackingEnabled: $locationTrackingEnabled, activityRecognitionEnabled: $activityRecognitionEnabled, notificationsEnabled: $notificationsEnabled, trackingPaused: $trackingPaused)';
}


}

/// @nodoc
abstract mixin class _$ProfileSettingsCopyWith<$Res> implements $ProfileSettingsCopyWith<$Res> {
  factory _$ProfileSettingsCopyWith(_ProfileSettings value, $Res Function(_ProfileSettings) _then) = __$ProfileSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool locationTrackingEnabled, bool activityRecognitionEnabled, bool notificationsEnabled, bool trackingPaused
});




}
/// @nodoc
class __$ProfileSettingsCopyWithImpl<$Res>
    implements _$ProfileSettingsCopyWith<$Res> {
  __$ProfileSettingsCopyWithImpl(this._self, this._then);

  final _ProfileSettings _self;
  final $Res Function(_ProfileSettings) _then;

/// Create a copy of ProfileSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationTrackingEnabled = null,Object? activityRecognitionEnabled = null,Object? notificationsEnabled = null,Object? trackingPaused = null,}) {
  return _then(_ProfileSettings(
locationTrackingEnabled: null == locationTrackingEnabled ? _self.locationTrackingEnabled : locationTrackingEnabled // ignore: cast_nullable_to_non_nullable
as bool,activityRecognitionEnabled: null == activityRecognitionEnabled ? _self.activityRecognitionEnabled : activityRecognitionEnabled // ignore: cast_nullable_to_non_nullable
as bool,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,trackingPaused: null == trackingPaused ? _self.trackingPaused : trackingPaused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ProfileState {

 ProfileSettings get settings; bool get isLoading; String? get error;
/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileStateCopyWith<ProfileState> get copyWith => _$ProfileStateCopyWithImpl<ProfileState>(this as ProfileState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileState&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,settings,isLoading,error);

@override
String toString() {
  return 'ProfileState(settings: $settings, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $ProfileStateCopyWith<$Res>  {
  factory $ProfileStateCopyWith(ProfileState value, $Res Function(ProfileState) _then) = _$ProfileStateCopyWithImpl;
@useResult
$Res call({
 ProfileSettings settings, bool isLoading, String? error
});


$ProfileSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$ProfileStateCopyWithImpl<$Res>
    implements $ProfileStateCopyWith<$Res> {
  _$ProfileStateCopyWithImpl(this._self, this._then);

  final ProfileState _self;
  final $Res Function(ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? settings = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProfileSettings,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileSettingsCopyWith<$Res> get settings {
  
  return $ProfileSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileState].
extension ProfileStatePatterns on ProfileState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileState value)  $default,){
final _that = this;
switch (_that) {
case _ProfileState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileState value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProfileSettings settings,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.settings,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProfileSettings settings,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ProfileState():
return $default(_that.settings,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProfileSettings settings,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.settings,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileState implements ProfileState {
  const _ProfileState({this.settings = const ProfileSettings(), this.isLoading = false, this.error});
  

@override@JsonKey() final  ProfileSettings settings;
@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileStateCopyWith<_ProfileState> get copyWith => __$ProfileStateCopyWithImpl<_ProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileState&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,settings,isLoading,error);

@override
String toString() {
  return 'ProfileState(settings: $settings, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ProfileStateCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$ProfileStateCopyWith(_ProfileState value, $Res Function(_ProfileState) _then) = __$ProfileStateCopyWithImpl;
@override @useResult
$Res call({
 ProfileSettings settings, bool isLoading, String? error
});


@override $ProfileSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$ProfileStateCopyWithImpl<$Res>
    implements _$ProfileStateCopyWith<$Res> {
  __$ProfileStateCopyWithImpl(this._self, this._then);

  final _ProfileState _self;
  final $Res Function(_ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? settings = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_ProfileState(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProfileSettings,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileSettingsCopyWith<$Res> get settings {
  
  return $ProfileSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
