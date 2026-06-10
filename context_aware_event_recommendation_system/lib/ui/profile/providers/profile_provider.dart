import 'package:context_aware_event_recommendation_system/ui/auth/providers/auth_provider.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_provider.freezed.dart';
part 'profile_provider.g.dart';

@freezed
abstract class ProfileSettings with _$ProfileSettings {
  const factory ProfileSettings({
    @Default(true) bool locationTrackingEnabled,
    @Default(true) bool activityRecognitionEnabled,
    @Default(true) bool notificationsEnabled,
    @Default(false) bool trackingPaused,
  }) = _ProfileSettings;
}

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(ProfileSettings()) ProfileSettings settings,
    @Default(false) bool isLoading,
    String? error,
  }) = _ProfileState;
}

@Riverpod(keepAlive: true)
class Profile extends _$Profile {
  // Keys are scoped to the current user so settings from user A
  // never bleed into user B's session.
  static String _kLocation(String uid) => 'profile_${uid}_location_tracking';
  static String _kActivity(String uid) => 'profile_${uid}_activity_recognition';
  static String _kNotifications(String uid) => 'profile_${uid}_notifications';
  static String _kPaused(String uid) => 'profile_${uid}_tracking_paused';

  @override
  ProfileState build() {
    final uid = ref.watch(authProvider).user?.id;
    // No authenticated user → return defaults without persisting.
    if (uid == null) return const ProfileState();

    final prefs = ref.read(sharedPreferencesProvider);
    return ProfileState(
      settings: ProfileSettings(
        locationTrackingEnabled: prefs.getBool(_kLocation(uid)) ?? true,
        activityRecognitionEnabled: prefs.getBool(_kActivity(uid)) ?? true,
        notificationsEnabled: prefs.getBool(_kNotifications(uid)) ?? true,
        trackingPaused: prefs.getBool(_kPaused(uid)) ?? false,
      ),
    );
  }

  void _update(ProfileSettings s) {
    state = state.copyWith(settings: s);
    final uid = ref.read(authProvider).user?.id;
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_kLocation(uid), s.locationTrackingEnabled);
    prefs.setBool(_kActivity(uid), s.activityRecognitionEnabled);
    prefs.setBool(_kNotifications(uid), s.notificationsEnabled);
    prefs.setBool(_kPaused(uid), s.trackingPaused);
  }

  void toggleLocationTracking() =>
      _update(state.settings.copyWith(locationTrackingEnabled: !state.settings.locationTrackingEnabled));

  void toggleActivityRecognition() =>
      _update(state.settings.copyWith(activityRecognitionEnabled: !state.settings.activityRecognitionEnabled));

  void toggleNotifications() =>
      _update(state.settings.copyWith(notificationsEnabled: !state.settings.notificationsEnabled));

  void toggleTrackingPause() =>
      _update(state.settings.copyWith(trackingPaused: !state.settings.trackingPaused));

  void updateSettings(ProfileSettings settings) => _update(settings);
}
