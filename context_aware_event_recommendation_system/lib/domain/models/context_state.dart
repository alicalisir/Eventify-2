import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/constants/app_strings.dart';

part 'context_state.freezed.dart';

@freezed
abstract class ContextState with _$ContextState {
  const ContextState._();

  const factory ContextState({
    required String greeting,
    required String contextDescription,
    @Default(false) bool isLocationEnabled,
    @Default(false) bool isNotificationsEnabled,
    DateTime? lastUpdated,
  }) = _ContextState;

  static ContextState initial() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? AppStrings.goodMorning
        : hour < 17
            ? AppStrings.goodAfternoon
            : AppStrings.goodEvening;
    return ContextState(
      greeting: greeting,
      contextDescription: 'Analyzing your current context...',
      lastUpdated: DateTime.now(),
    );
  }
}
