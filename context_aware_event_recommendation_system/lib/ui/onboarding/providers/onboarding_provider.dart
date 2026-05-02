import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

class OnboardingState {
  final int currentPage;
  final bool locationGranted;
  final bool notificationsGranted;
  final bool isComplete;

  const OnboardingState({
    this.currentPage = 0,
    this.locationGranted = false,
    this.notificationsGranted = false,
    this.isComplete = false,
  });

  OnboardingState copyWith({
    int? currentPage,
    bool? locationGranted,
    bool? notificationsGranted,
    bool? isComplete,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      locationGranted: locationGranted ?? this.locationGranted,
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

@riverpod
class Onboarding extends _$Onboarding {
  @override
  OnboardingState build() => const OnboardingState();

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void grantLocation() {
    state = state.copyWith(locationGranted: true);
  }

  void grantNotifications() {
    state = state.copyWith(notificationsGranted: true);
  }

  void complete() {
    state = state.copyWith(isComplete: true);
  }
}
