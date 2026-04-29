import '../../domain/models/suggestion_model.dart';
import '../../domain/models/persona_model.dart';
import '../../domain/models/context_state.dart';

/// Context service - Mock implementation
/// TODO: Replace with real AI/ML service and sensor data
class ContextService {
  /// Get AI-generated suggestions based on current context
  Future<List<SuggestionModel>> getSuggestions() async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock suggestions for demo
    return [
      SuggestionModel(
        id: 'sug_1',
        title: 'Visit the Museum of Modern Art',
        description:
            'Explore contemporary art exhibitions featuring local and international artists. Perfect for your current mood and free time.',
        rationale:
            'Based on your creative persona and current location, this cultural experience aligns with your interests in art and learning.',
        category: 'Cultural',
        imageUrl: 'https://picsum.photos/400/300?random=1',
        distance: 2.3,
        estimatedMinutes: 45,
        address: '123 Art Street, Downtown',
        latitude: 40.7614,
        longitude: -73.9776,
        tags: ['art', 'culture', 'indoor', 'educational'],
        createdAt: DateTime.now(),
      ),
      SuggestionModel(
        id: 'sug_2',
        title: 'Sunset Walk at Riverside Park',
        description:
            'Enjoy a peaceful walk along the river as the sun sets. Great for reflection and relaxation.',
        rationale:
            'Your current stress levels and preference for outdoor activities make this a perfect choice for unwinding.',
        category: 'Recreation',
        imageUrl: 'https://picsum.photos/400/300?random=2',
        distance: 1.5,
        estimatedMinutes: 30,
        address: 'Riverside Park, East Side',
        latitude: 40.7829,
        longitude: -73.9654,
        tags: ['outdoor', 'nature', 'relaxation', 'free'],
        createdAt: DateTime.now(),
      ),
      SuggestionModel(
        id: 'sug_3',
        title: 'Coffee & Coworking at Brew Station',
        description:
            'Productive atmosphere with excellent coffee. Ideal for focused work or casual meetings.',
        rationale:
            'Based on your work schedule and energy levels, a change of environment could boost productivity.',
        category: 'Work',
        imageUrl: 'https://picsum.photos/400/300?random=3',
        distance: 0.8,
        estimatedMinutes: 15,
        address: '456 Main Street',
        latitude: 40.7589,
        longitude: -73.9851,
        tags: ['coffee', 'work', 'wifi', 'quiet'],
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Get current user context (location, time, activity, etc.)
  Future<ContextState> getCurrentContext() async {
    // Simulate sensor data collection
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock context for demo
    final now = DateTime.now();
    final timeOfDay = _getTimeOfDay(now);
    final dayOfWeek = _getDayOfWeek(now.weekday);

    return ContextState(
      greeting: 'Good $timeOfDay',
      contextDescription:
          'It\'s $dayOfWeek $timeOfDay in Downtown Area. Weather is sunny and suitable for outdoor plans.',
      isLocationEnabled: true,
      isNotificationsEnabled: true,
      lastUpdated: now,
    );
  }

  /// Get user persona based on preferences and history
  Future<PersonaModel> getUserPersona() async {
    // Simulate ML model inference
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock persona for demo
    return PersonaModel(
      traits: [
        'Creative',
        'Curious',
        'Active',
        'Social',
        'Adventurous',
      ],
      preferences: {
        'culture': 0.9,
        'outdoor': 0.8,
        'food': 0.7,
        'productivity': 0.6,
      },
      lastUpdated: DateTime.now(),
    );
  }

  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour < 6) return 'Night';
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  String _getDayOfWeek(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}
