// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlaceModel _$PlaceModelFromJson(Map<String, dynamic> json) => _PlaceModel(
  id: json['id'] as String,
  name: json['name'] as String,
  types:
      (json['types'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  distanceMeters: (json['distanceMeters'] as num).toDouble(),
  address: json['address'] as String?,
  rating: (json['rating'] as num?)?.toDouble(),
  priceLevel: json['priceLevel'] as String?,
);

Map<String, dynamic> _$PlaceModelToJson(_PlaceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'types': instance.types,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'distanceMeters': instance.distanceMeters,
      'address': instance.address,
      'rating': instance.rating,
      'priceLevel': instance.priceLevel,
    };
