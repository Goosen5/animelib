import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/user_profile.dart';

class UserProfileService {
  UserProfileService();

  supabase.User? get _currentUser {
    try {
      return supabase.Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String _requireUserId() {
    final uid = _currentUser?.id;
    if (uid == null) {
      throw Exception('Not authenticated');
    }
    return uid;
  }

  String _requireUserEmail() {
    return _currentUser?.email ?? '';
  }

  Future<UserProfile> getProfile() async {
    final userId = _requireUserId();
    final email = _requireUserEmail();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));

    if (raw == null || raw.isEmpty) {
      return UserProfile(id: userId, email: email);
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return UserProfile.fromJson(decoded);
  }

  Future<UserProfile> upsertProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    final userId = _requireUserId();
    final email = _requireUserEmail();
    final now = DateTime.now();

    final existing = await getProfile();
    final profile = UserProfile(
      id: userId,
      email: email,
      displayName: displayName.trim().isEmpty ? null : displayName.trim(),
      avatarUrl: (avatarUrl == null || avatarUrl.trim().isEmpty)
          ? null
          : avatarUrl.trim(),
      createdAt: existing.createdAt ?? now,
      updatedAt: now,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyForUser(userId),
      jsonEncode({
        'id': profile.id,
        'email': profile.email,
        'display_name': profile.displayName,
        'avatar_url': profile.avatarUrl,
        'created_at': profile.createdAt?.toIso8601String(),
        'updated_at': profile.updatedAt?.toIso8601String(),
      }),
    );

    return profile;
  }

  String _keyForUser(String userId) => 'local_profile_$userId';
}
