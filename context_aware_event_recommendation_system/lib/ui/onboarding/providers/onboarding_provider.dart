import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onboarding state
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

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

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

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
