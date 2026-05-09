import 'package:freezed_annotation/freezed_annotation.dart';

part 'place_model.freezed.dart';
part 'place_model.g.dart';

@freezed
abstract class PlaceModel with _$PlaceModel {
  const factory PlaceModel({
    required String id,
    required String name,

    /// Google Places type list e.g. ["restaurant", "food", "establishment"].
    /// First element is the most specific type — use for ML feature and LLM prompt.
    @Default(<String>[]) List<String> types,
    required double latitude,
    required double longitude,

    /// Straight-line distance from user in metres.
    required double distanceMeters,
    String? address,
    double? rating,

    /// PRICE_LEVEL_FREE / INEXPENSIVE / MODERATE / EXPENSIVE / VERY_EXPENSIVE
    String? priceLevel,
  }) = _PlaceModel;

  factory PlaceModel.fromJson(Map<String, dynamic> json) =>
      _$PlaceModelFromJson(json);
}
