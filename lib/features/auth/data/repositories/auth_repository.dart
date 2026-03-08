import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/data/models/profile_model.dart';

/// Repository handling all Supabase Authentication operations
/// and profile fetching from the `profiles` + `roles` tables.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /// Sign in with email and password.
  /// Throws [AuthException] on failure.
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  /// Fetch the current user's profile joined with their role.
  /// Returns null if no row exists yet in `profiles`.
  Future<ProfileModel?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, phone_number, is_active, roles(role_name)')
          .eq('id', userId)
          .single();
      return ProfileModel.fromJson(data);
    } on PostgrestException catch (e) {
      // PGRST116 = "The result contains 0 rows" — profile not created yet
      if (e.code == 'PGRST116') return null;
      rethrow;
    } catch (_) {
      return null;
    }
  }
}

/// Global provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});
