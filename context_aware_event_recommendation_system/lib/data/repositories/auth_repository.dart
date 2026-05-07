import '../../domain/models/user_model.dart';
import '../services/auth_service.dart';

/// Owns the authenticated user lifecycle: sign-in/up/out via [AuthService].
/// Session persistence is handled automatically by supabase_flutter.
class AuthRepository {
  AuthRepository(this._authService);

  final AuthService _authService;

  Future<UserModel?> signIn(String email, String password) async {
    return _authService.signIn(email, password);
  }

  Future<UserModel?> signUp(String name, String email, String password) async {
    return _authService.signUp(name, email, password);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Checks for an active Supabase session and fetches the user profile.
  Future<UserModel?> restoreSession() async {
    return _authService.getSessionUser();
  }

  Future<UserModel> markOnboardingCompleted(UserModel user) async {
    await _authService.updateOnboardingCompleted(user.id);
    return user.copyWith(hasCompletedOnboarding: true);
  }

  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordReset(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _authService.updatePassword(newPassword);
  }
}
