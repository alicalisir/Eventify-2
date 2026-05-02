import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.freezed.dart';
part 'onboarding_provider.g.dart';

@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentPage,
    @Default(false) bool locationGranted,
    @Default(false) bool notificationsGranted,
    @Default(false) bool isComplete,
  }) = _OnboardingState;
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
