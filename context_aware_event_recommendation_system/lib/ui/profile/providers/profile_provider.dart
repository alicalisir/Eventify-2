import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/persona_model.dart';

/// Persona provider - manages user persona data
final personaProvider = FutureProvider<PersonaModel>((ref) async {
  // TODO: Load from actual data source
  await Future.delayed(const Duration(milliseconds: 500));
  return PersonaModel(
    traits: ['Adventurous', 'Social', 'Foodie', 'Active', 'Culture Enthusiast'],
    preferences: {},
    lastUpdated: DateTime.now(),
  );
});

/// Profile provider - manages profile and user settings state
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

class ProfileSettings {
  final bool locationTrackingEnabled;
  final bool activityRecognitionEnabled;
  final bool notificationsEnabled;
  final bool trackingPaused;

  const ProfileSettings({
    this.locationTrackingEnabled = true,
    this.activityRecognitionEnabled = true,
    this.notificationsEnabled = true,
    this.trackingPaused = false,
  });

  ProfileSettings copyWith({
    bool? locationTrackingEnabled,
    bool? activityRecognitionEnabled,
    bool? notificationsEnabled,
    bool? trackingPaused,
  }) {
    return ProfileSettings(
      locationTrackingEnabled:
          locationTrackingEnabled ?? this.locationTrackingEnabled,
      activityRecognitionEnabled:
          activityRecognitionEnabled ?? this.activityRecognitionEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      trackingPaused: trackingPaused ?? this.trackingPaused,
    );
  }
}

class ProfileState {
  final ProfileSettings settings;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.settings = const ProfileSettings(),
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    ProfileSettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState());

  void toggleLocationTracking() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        locationTrackingEnabled: !state.settings.locationTrackingEnabled,
      ),
    );
  }

  void toggleActivityRecognition() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        activityRecognitionEnabled: !state.settings.activityRecognitionEnabled,
      ),
    );
  }

  void toggleNotifications() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        notificationsEnabled: !state.settings.notificationsEnabled,
      ),
    );
  }

  void toggleTrackingPause() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        trackingPaused: !state.settings.trackingPaused,
      ),
    );
  }

  void updateSettings(ProfileSettings settings) {
    state = state.copyWith(settings: settings);
  }
}
