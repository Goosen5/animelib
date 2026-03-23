import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Core auth stream — drives navigation throughout the app.
// Emits the current [User] (authenticated) or null (signed-out).
// Supabase Auth persists the session automatically across restarts.
// ---------------------------------------------------------------------------
final authStateChangesProvider = StreamProvider<supabase.User?>((ref) {
  try {
    return ref.read(authServiceProvider).authStateChanges;
  } catch (_) {
    // Supabase not initialized.
    // Emit null so AuthGate routes to the login screen rather than hanging.
    return Stream.value(null);
  }
});

// ---------------------------------------------------------------------------
// Singleton service provider.
// ---------------------------------------------------------------------------
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ---------------------------------------------------------------------------
// Mutation controller — manages loading / error state for sign-in/up/out.
// The UI reads `authControllerProvider` to show a spinner or error banner.
// ---------------------------------------------------------------------------
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial async work needed; state starts as AsyncData(null).
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authServiceProvider)
          .signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authServiceProvider)
          .signUp(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signOut(),
    );
  }
}
