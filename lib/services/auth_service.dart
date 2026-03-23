import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'supabase_init_service.dart';

/// Human-readable messages for common Supabase auth errors.
String _authErrorMessage(supabase.AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Invalid email or password. Please check and try again.';
    case 'email_not_confirmed':
      return 'Please confirm your email before signing in.';
    case 'email_address_invalid':
      return 'The email address is not valid.';
    case 'user_already_exists':
      return 'An account with this email already exists.';
    case 'weak_password':
      return 'Password is too weak. Use at least 6 characters.';
    default:
      return e.message;
  }
}

/// Wraps Supabase Auth with clean async methods and friendly error messages.
class AuthService {
  AuthService._();

  factory AuthService() => _instance;
  static final AuthService _instance = AuthService._();

  void _ensureInitialized() {
    if (!SupabaseInitService.isInitialized) {
      throw const AuthException(
        'Supabase is not configured. Run with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }

  supabase.GoTrueClient get _auth {
    _ensureInitialized();
    return supabase.Supabase.instance.client.auth;
  }

  /// The currently signed-in user, or null.
  supabase.User? get currentUser {
    if (!SupabaseInitService.isInitialized) {
      return null;
    }
    return _auth.currentUser;
  }

  /// Emits [User] on sign-in, null on sign-out.
  Stream<supabase.User?> get authStateChanges {
    if (!SupabaseInitService.isInitialized) {
      return Stream.value(null);
    }
    return _auth.onAuthStateChange.map((event) => event.session?.user);
  }

  /// Signs in with [email] and [password].
  /// Throws an [AuthException] with a user-friendly message on failure.
  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _ensureInitialized();
    try {
      return await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Creates a new account with [email] and [password].
  /// Throws an [AuthException] with a user-friendly message on failure.
  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    _ensureInitialized();
    try {
      return await _auth.signUp(
        email: email.trim(),
        password: password,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    _ensureInitialized();
    await _auth.signOut();
  }
}

/// Thrown by [AuthService] with a human-readable [message].
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
