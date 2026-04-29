import '../../domain/models/user_model.dart';

/// Authentication service - Mock implementation
/// TODO: Replace with real Firebase/Supabase authentication
class AuthService {
  UserModel? _currentUser;

  /// Sign in with email and password
  Future<UserModel?> signIn(String email, String password) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock authentication - accept any email/password for demo
    if (email.isNotEmpty && password.length >= 6) {
      _currentUser = UserModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email,
        hasCompletedOnboarding: false,
        createdAt: DateTime.now(),
      );
      return _currentUser;
    }

    return null;
  }

  /// Sign up with name, email and password
  Future<UserModel?> signUp(String name, String email, String password) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock sign up - accept any valid input for demo
    if (name.isNotEmpty && email.isNotEmpty && password.length >= 6) {
      _currentUser = UserModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        hasCompletedOnboarding: false,
        createdAt: DateTime.now(),
      );
      return _currentUser;
    }

    return null;
  }

  /// Sign out current user
  Future<void> signOut() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  /// Get current user
  UserModel? getCurrentUser() {
    return _currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _currentUser != null;
  }
}
