import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'anime_home_screen.dart';
import 'auth_screen.dart';

/// Top-level navigation gate.
/// Reacts to the Supabase auth stream and routes accordingly.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      // Show a splash while the initial auth state is loading from persistence.
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, stack) => const AuthScreen(),
      data: (user) {
        if (user != null) {
          return const AnimeHomeScreen(title: 'Singularity');
        }
        return const AuthScreen();
      },
    );
  }
}
