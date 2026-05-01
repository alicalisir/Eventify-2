import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/user_model.dart';
import '../services/auth_service.dart';

/// Owns the authenticated user lifecycle: sign-in/up/out via [AuthService]
/// plus session persistence so the user stays signed in across restarts.
class AuthRepository {
  AuthRepository(this._authService, this._prefs);

  final AuthService _authService;
  final SharedPreferences _prefs;

  static const _userKey = 'auth.current_user';

  Future<UserModel?> signIn(String email, String password) async {
    final user = await _authService.signIn(email, password);
    if (user != null) {
      await _persist(user);
    }
    return user;
  }

  Future<UserModel?> signUp(String name, String email, String password) async {
    final user = await _authService.signUp(name, email, password);
    if (user != null) {
      await _persist(user);
    }
    return user;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await _prefs.remove(_userKey);
  }

  /// Hydrates the previously persisted user, if any.
  Future<UserModel?> restoreSession() async {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return _decode(raw);
    } catch (_) {
      await _prefs.remove(_userKey);
      return null;
    }
  }

  Future<UserModel> markOnboardingCompleted(UserModel user) async {
    final updated = user.copyWith(hasCompletedOnboarding: true);
    await _persist(updated);
    return updated;
  }

  Future<void> _persist(UserModel user) async {
    await _prefs.setString(_userKey, _encode(user));
  }

  String _encode(UserModel user) => jsonEncode({
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'avatarUrl': user.avatarUrl,
        'hasCompletedOnboarding': user.hasCompletedOnboarding,
        'createdAt': user.createdAt.toIso8601String(),
      });

  UserModel _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hasCompletedOnboarding:
          json['hasCompletedOnboarding'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
