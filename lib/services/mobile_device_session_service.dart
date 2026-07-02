import 'dart:io' show Platform;

import 'package:learining_portal/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists the install-scoped device id and server mobile session token.
class MobileDeviceSessionService {
  MobileDeviceSessionService._();

  static const _uuid = Uuid();

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(prefsKeyMobileDeviceId)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = _uuid.v4();
    await prefs.setString(prefsKeyMobileDeviceId, id);
    return id;
  }

  static String getDeviceLabel() {
    try {
      final os = Platform.operatingSystem;
      final ver = Platform.operatingSystemVersion.trim();
      if (ver.isEmpty) return os;
      if (ver.length > 200) {
        return '$os ${ver.substring(0, 200)}';
      }
      return '$os $ver';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<void> saveSessionToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKeyMobileSessionToken, trimmed);
  }

  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(prefsKeyMobileSessionToken)?.trim();
    return (token != null && token.isNotEmpty) ? token : null;
  }

  static Future<void> clearSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyMobileSessionToken);
  }
}
