/// Suggestion model for AI recommendations
class SuggestionModel {
  final String id;
  final String title;
  final String description;
  final String rationale;
  final String category;
  final String? imageUrl;
  final double? distance;
  final int? estimatedMinutes;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> tags;
  final DateTime createdAt;

  const SuggestionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rationale,
    required this.category,
    this.imageUrl,
    this.distance,
    this.estimatedMinutes,
    this.address,
    this.latitude,
    this.longitude,
    this.tags = const [],
    required this.createdAt,
  });
}
