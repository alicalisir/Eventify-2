import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_model.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Future<UserModel?> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) return null;
    return _fetchUserProfile(response.user!.id, email);
  }

  Future<UserModel?> signUp(String name, String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    if (response.user == null) return null;

    await _client.from('users').insert({
      'id': response.user!.id,
      'email': email,
      'name': name,
      'has_completed_onboarding': false,
    });

    return UserModel(
      id: response.user!.id,
      email: email,
      name: name,
      hasCompletedOnboarding: false,
      createdAt: DateTime.now(),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Returns the user from the current Supabase session, null if not signed in.
  Future<UserModel?> getSessionUser() async {
    final supaUser = _client.auth.currentUser;
    if (supaUser == null) return null;
    return _fetchUserProfile(supaUser.id, supaUser.email ?? '');
  }

  Future<void> updateOnboardingCompleted(String userId) async {
    await _client
        .from('users')
        .update({'has_completed_onboarding': true}).eq('id', userId);
  }

  Future<void> updateInterestsAndConsent({
    required String userId,
    required List<String> interests,
    DateTime? consentAt,
  }) async {
    await _client.from('users').update({
      'interests': interests,
      if (consentAt != null) 'consent_given_at': consentAt.toIso8601String(),
    }).eq('id', userId);
  }

  Future<UserModel?> _fetchUserProfile(
    String id,
    String fallbackEmail,
  ) async {
    final data =
        await _client.from('users').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return UserModel(
      id: data['id'] as String,
      email: data['email'] as String? ?? fallbackEmail,
      name: data['name'] as String? ?? '',
      hasCompletedOnboarding:
          data['has_completed_onboarding'] as bool? ?? false,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
