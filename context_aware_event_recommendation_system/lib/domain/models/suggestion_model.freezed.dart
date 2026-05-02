// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'suggestion_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SuggestionModel {

 String get id; String get title; String get description;/// Why the AI surfaced this — visible inside cards and detail view.
 String get rationale;/// Category string is the single source of truth for icon and hue.
/// Use [SuggestionCategoryX] extension to derive display values.
 String get category;/// Distance in km, null if not location-bound.
 double? get distance;/// Estimated minutes for the activity.
 int? get estimatedMinutes; String? get address; double? get latitude; double? get longitude; List<String> get tags;/// Optional context-weather summary (e.g. "21° • Clear").
 String? get weather; DateTime get createdAt;
/// Create a copy of SuggestionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuggestionModelCopyWith<SuggestionModel> get copyWith => _$SuggestionModelCopyWithImpl<SuggestionModel>(this as SuggestionModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SuggestionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.category, category) || other.category == category)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.estimatedMinutes, estimatedMinutes) || other.estimatedMinutes == estimatedMinutes)&&(identical(other.address, address) || other.address == address)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.weather, weather) || other.weather == weather)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,rationale,category,distance,estimatedMinutes,address,latitude,longitude,const DeepCollectionEquality().hash(tags),weather,createdAt);

@override
String toString() {
  return 'SuggestionModel(id: $id, title: $title, description: $description, rationale: $rationale, category: $category, distance: $distance, estimatedMinutes: $estimatedMinutes, address: $address, latitude: $latitude, longitude: $longitude, tags: $tags, weather: $weather, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SuggestionModelCopyWith<$Res>  {
  factory $SuggestionModelCopyWith(SuggestionModel value, $Res Function(SuggestionModel) _then) = _$SuggestionModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, String rationale, String category, double? distance, int? estimatedMinutes, String? address, double? latitude, double? longitude, List<String> tags, String? weather, DateTime createdAt
});




}
/// @nodoc
class _$SuggestionModelCopyWithImpl<$Res>
    implements $SuggestionModelCopyWith<$Res> {
  _$SuggestionModelCopyWithImpl(this._self, this._then);

  final SuggestionModel _self;
  final $Res Function(SuggestionModel) _then;

/// Create a copy of SuggestionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? rationale = null,Object? category = null,Object? distance = freezed,Object? estimatedMinutes = freezed,Object? address = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? tags = null,Object? weather = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SuggestionModel].
extension SuggestionModelPatterns on SuggestionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SuggestionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SuggestionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SuggestionModel value)  $default,){
final _that = this;
switch (_that) {
case _SuggestionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SuggestionModel value)?  $default,){
final _that = this;
switch (_that) {
case _SuggestionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String rationale,  String category,  double? distance,  int? estimatedMinutes,  String? address,  double? latitude,  double? longitude,  List<String> tags,  String? weather,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SuggestionModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.rationale,_that.category,_that.distance,_that.estimatedMinutes,_that.address,_that.latitude,_that.longitude,_that.tags,_that.weather,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String rationale,  String category,  double? distance,  int? estimatedMinutes,  String? address,  double? latitude,  double? longitude,  List<String> tags,  String? weather,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SuggestionModel():
return $default(_that.id,_that.title,_that.description,_that.rationale,_that.category,_that.distance,_that.estimatedMinutes,_that.address,_that.latitude,_that.longitude,_that.tags,_that.weather,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  String rationale,  String category,  double? distance,  int? estimatedMinutes,  String? address,  double? latitude,  double? longitude,  List<String> tags,  String? weather,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SuggestionModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.rationale,_that.category,_that.distance,_that.estimatedMinutes,_that.address,_that.latitude,_that.longitude,_that.tags,_that.weather,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _SuggestionModel implements SuggestionModel {
  const _SuggestionModel({required this.id, required this.title, required this.description, required this.rationale, required this.category, this.distance, this.estimatedMinutes, this.address, this.latitude, this.longitude, final  List<String> tags = const <String>[], this.weather, required this.createdAt}): _tags = tags;
  

@override final  String id;
@override final  String title;
@override final  String description;
/// Why the AI surfaced this — visible inside cards and detail view.
@override final  String rationale;
/// Category string is the single source of truth for icon and hue.
/// Use [SuggestionCategoryX] extension to derive display values.
@override final  String category;
/// Distance in km, null if not location-bound.
@override final  double? distance;
/// Estimated minutes for the activity.
@override final  int? estimatedMinutes;
@override final  String? address;
@override final  double? latitude;
@override final  double? longitude;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Optional context-weather summary (e.g. "21° • Clear").
@override final  String? weather;
@override final  DateTime createdAt;

/// Create a copy of SuggestionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuggestionModelCopyWith<_SuggestionModel> get copyWith => __$SuggestionModelCopyWithImpl<_SuggestionModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SuggestionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.category, category) || other.category == category)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.estimatedMinutes, estimatedMinutes) || other.estimatedMinutes == estimatedMinutes)&&(identical(other.address, address) || other.address == address)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.weather, weather) || other.weather == weather)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,rationale,category,distance,estimatedMinutes,address,latitude,longitude,const DeepCollectionEquality().hash(_tags),weather,createdAt);

@override
String toString() {
  return 'SuggestionModel(id: $id, title: $title, description: $description, rationale: $rationale, category: $category, distance: $distance, estimatedMinutes: $estimatedMinutes, address: $address, latitude: $latitude, longitude: $longitude, tags: $tags, weather: $weather, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SuggestionModelCopyWith<$Res> implements $SuggestionModelCopyWith<$Res> {
  factory _$SuggestionModelCopyWith(_SuggestionModel value, $Res Function(_SuggestionModel) _then) = __$SuggestionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, String rationale, String category, double? distance, int? estimatedMinutes, String? address, double? latitude, double? longitude, List<String> tags, String? weather, DateTime createdAt
});




}
/// @nodoc
class __$SuggestionModelCopyWithImpl<$Res>
    implements _$SuggestionModelCopyWith<$Res> {
  __$SuggestionModelCopyWithImpl(this._self, this._then);

  final _SuggestionModel _self;
  final $Res Function(_SuggestionModel) _then;

/// Create a copy of SuggestionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? rationale = null,Object? category = null,Object? distance = freezed,Object? estimatedMinutes = freezed,Object? address = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? tags = null,Object? weather = freezed,Object? createdAt = null,}) {
  return _then(_SuggestionModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
