import 'dart:io';

import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/app_error.dart';
import 'package:context_aware_event_recommendation_system/domain/models/user_model.dart';
import 'package:context_aware_event_recommendation_system/utils/app_logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:context_aware_event_recommendation_system/di/providers.dart'
    show sharedPreferencesProvider;

part 'auth_provider.freezed.dart';
part 'auth_provider.g.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, passwordRecovery }

@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.initial) AuthStatus status,
    UserModel? user,
    AppError? error,
  }) = _AuthState;
}

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  AuthState build() {
    final subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        switch (data.event) {
          case AuthChangeEvent.passwordRecovery:
            AppLogger.i('[Auth] Password recovery session detected');
            state = state.copyWith(status: AuthStatus.passwordRecovery);
          case AuthChangeEvent.tokenRefreshed:
            AppLogger.d('[Auth] Token refreshed');
          case AuthChangeEvent.signedOut:
            AppLogger.i('[Auth] Signed out via external event');
            state = const AuthState(status: AuthStatus.unauthenticated);
          // ignore: deprecated_member_use
          case AuthChangeEvent.userDeleted:
            AppLogger.w('[Auth] User deleted externally');
            state = const AuthState(status: AuthStatus.unauthenticated);
          default:
            break;
        }
      },
    );
    ref.onDispose(subscription.cancel);
    return const AuthState();
  }

  Future<void> restoreSession() async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .restoreSession()
          .timeout(const Duration(seconds: 3));
      if (user != null) {
        AppLogger.i('[Auth] Session restored → ${user.email}');
      } else {
        AppLogger.i('[Auth] No persisted session found');
      }
      state = AuthState(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
      );
    } catch (e, s) {
      AppLogger.e('[Auth] Session restore failed or timed out', e, s);
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email, password);
      if (user != null) {
        AppLogger.i('[Auth] signIn success → ${user.email}');
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return true;
      }
      AppLogger.w('[Auth] signIn rejected (invalid credentials)');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: const AuthError(),
      );
      return false;
    } catch (e, s) {
      final err = _classify(e);
      AppLogger.e('[Auth] signIn failed', e, s);
      state = state.copyWith(status: AuthStatus.unauthenticated, error: err);
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signUp(name, email, password);
      if (user != null) {
        AppLogger.i('[Auth] signUp success → ${user.email}');
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return true;
      }
      AppLogger.w('[Auth] signUp rejected');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: const UnknownError(),
      );
      return false;
    } catch (e, s) {
      final err = _classify(e);
      AppLogger.e('[Auth] signUp failed', e, s);
      state = state.copyWith(status: AuthStatus.unauthenticated, error: err);
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    final user = state.user;
    if (user == null) return;
    final updated = await ref
        .read(authRepositoryProvider)
        .markOnboardingCompleted(user);
    state = state.copyWith(user: updated);
  }

  Future<void> signOut() async {
    // Clear user-specific in-memory caches before the session ends so
    // the next user never briefly sees the previous user's data.
    ref.read(suggestionRepositoryProvider).invalidateCache();
    ref.read(contextRepositoryProvider).invalidateContext();
    ref.read(contextRepositoryProvider).invalidatePersona();
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      AppLogger.i('[Auth] Password reset email sent to $email');
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return true;
    } catch (e, s) {
      AppLogger.e('[Auth] sendPasswordReset failed', e, s);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _classify(e),
      );
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      final user = await ref.read(authRepositoryProvider).restoreSession();
      AppLogger.i('[Auth] Password updated successfully');
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e, s) {
      AppLogger.e('[Auth] updatePassword failed', e, s);
      state = state.copyWith(
        status: AuthStatus.passwordRecovery,
        error: _classify(e),
      );
      return false;
    }
  }

  Future<bool> updateName(String name) async {
    final user = state.user;
    if (user == null) return false;
    try {
      await ref.read(authRepositoryProvider).updateProfileName(user.id, name);
      state = state.copyWith(user: user.copyWith(name: name));
      AppLogger.i('[Auth] Profile name updated');
      return true;
    } catch (e, s) {
      AppLogger.e('[Auth] updateName failed', e, s);
      return false;
    }
  }

  static AppError _classify(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') ||
          msg.contains('too many') ||
          msg.contains('over_email_send_rate_limit')) {
        return const TooManyRequestsError();
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('not confirmed')) {
        return const EmailNotVerifiedError();
      }
      if (msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        return const AuthError();
      }
      if (msg.contains('network') || msg.contains('timeout')) {
        return const NetworkError();
      }
      return const AuthError();
    }
    if (e is SocketException || e is HttpException) return const NetworkError();
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection')) {
      return const NetworkError();
    }
    return const UnknownError();
  }
}
