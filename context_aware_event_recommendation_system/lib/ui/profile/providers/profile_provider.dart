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
  @override
  ProfileState build() => const ProfileState();

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
