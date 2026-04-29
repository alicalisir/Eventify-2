import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_aware_event_recommendation_system/data/services/auth_service.dart';
import 'package:context_aware_event_recommendation_system/domain/models/user_model.dart';

/// Auth state
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
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _authService.signIn(email, password);
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
      final user = await _authService.signUp(name, email, password);
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

  void completeOnboarding() {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(hasCompletedOnboarding: true),
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Providers
final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
