import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../di/providers.dart';

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

  Future<void> grantLocation() async {
    final granted =
        await ref.read(locationRepositoryProvider).requestPermission();
    state = state.copyWith(locationGranted: granted);
    if (granted) ref.read(contextRepositoryProvider).invalidateContext();
  }

  Future<void> grantNotifications() async {
    final status = await Permission.notification.request();
    state = state.copyWith(notificationsGranted: status.isGranted);
    if (status.isGranted) ref.read(contextRepositoryProvider).invalidateContext();
  }

  void complete() {
    state = state.copyWith(isComplete: true);
  }
}
