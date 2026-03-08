import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/data/models/profile_model.dart';
import 'package:laidani_repair/features/auth/data/repositories/auth_repository.dart';

// ─── Auth State Stream ─────────────────────────────────────────────────────

/// Streams every [AuthState] change from Supabase (login, logout, refresh…).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// ─── Current User ─────────────────────────────────────────────────────────

/// Synchronously derives the current [User] from the auth stream.
/// Returns null while loading or on error (treated as "not logged in").
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data: (state) => state.session?.user,
    // While stream hasn't emitted yet, fall back to the cached session
    loading: () => Supabase.instance.client.auth.currentSession?.user,
    error: (_, __) => null,
  );
});

// ─── Profile ──────────────────────────────────────────────────────────────

/// Fetches (and caches) the current user's [ProfileModel] via a DB query.
/// Automatically re-fetches when the user changes (login / logout cycle).
final profileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.read(authRepositoryProvider);
  return repo.fetchProfile(user.id);
});

// ─── Derived Role Helpers ──────────────────────────────────────────────────

/// Synchronous convenience: is the current user an owner?
/// Returns false while the profile is still loading.
final isOwnerProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).maybeWhen(
        data: (profile) => profile?.isOwner ?? false,
        orElse: () => false,
      );
});

/// The current user's role name ('owner' | 'worker' | null).
final currentRoleProvider = Provider<String?>((ref) {
  return ref.watch(profileProvider).maybeWhen(
        data: (profile) => profile?.roleName,
        orElse: () => null,
      );
});

// ─── Auth Notifier (for sign-in / sign-out actions) ───────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signIn(email, password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.signOut());
    // Invalidate the cached profile so the next login gets a fresh fetch
    _ref.invalidate(profileProvider);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});
