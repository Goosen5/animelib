import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseInitService {
  const SupabaseInitService._();

  static const String _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKeyFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get _url =>
      _urlFromDefine.isNotEmpty ? _urlFromDefine : SupabaseConfig.url;
  static String get _anonKey =>
      _anonKeyFromDefine.isNotEmpty ? _anonKeyFromDefine : SupabaseConfig.anonKey;

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (_url.isEmpty || _anonKey.isEmpty) {
      debugPrint(
        'Supabase is not configured. Set values in lib/services/supabase_config.dart '
        'or pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
      return;
    }

    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );

    _isInitialized = true;
  }

  static bool get isInitialized => _isInitialized;
}
