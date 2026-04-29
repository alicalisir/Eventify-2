import '../../config/constants/app_strings.dart';

/// User context state for dashboard
class ContextState {
  final String greeting;
  final String contextDescription;
  final bool isLocationEnabled;
  final bool isNotificationsEnabled;
  final DateTime? lastUpdated;

  const ContextState({
    required this.greeting,
    required this.contextDescription,
    this.isLocationEnabled = false,
    this.isNotificationsEnabled = false,
    this.lastUpdated,
  });

  static ContextState initial() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = AppStrings.goodMorning;
    } else if (hour < 17) {
      greeting = AppStrings.goodAfternoon;
    } else {
      greeting = AppStrings.goodEvening;
    }

    return ContextState(
      greeting: greeting,
      contextDescription: 'Analyzing your current context...',
      lastUpdated: DateTime.now(),
    );
  }
}
