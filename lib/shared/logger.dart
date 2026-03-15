import 'package:flutter/foundation.dart';

/// Lightweight debug logger. All output is suppressed in release builds.
///
/// Usage:
///   Log.auth('OTP sent → $email');
///   Log.nav('/dashboard');
///   Log.blocking('activated — 4 apps blocked');
///   Log.error('auth', e);
abstract final class Log {
  static void auth(String msg) => _out('🔐 auth', msg);
  static void nav(String msg) => _out('🧭 nav', msg);
  static void blocking(String msg) => _out('🚫 blocking', msg);
  static void db(String msg) => _out('🗄️  db', msg);
  static void boot(String msg) => _out('🚀 boot', msg);
  static void error(String tag, Object e) => _out('💥 $tag', '$e');

  static void _out(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }
}
