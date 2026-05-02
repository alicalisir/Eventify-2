import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_aware_event_recommendation_system/data/repositories/auth_repository.dart';
import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/user_model.dart';

export 'package:context_aware_event_recommendation_system/di/providers.dart'
    show sharedPreferencesProvider;

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<void> restoreSession() async {
    final user = await _repository.restoreSession();
    state = AuthState(
      status: user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: user,
    );
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repository.signIn(email, password);
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Invalid credentials. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repository.signUp(name, email, password);
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    final user = state.user;
    if (user == null) return;
    final updated = await _repository.markOnboardingCompleted(user);
    state = state.copyWith(user: updated);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
