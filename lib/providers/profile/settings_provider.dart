import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kNotificationsEnabledKey = 'notifications_enabled';

/// App settings (notifications, etc.) persisted in SharedPreferences.
class SettingsProvider with ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _loaded = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get loaded => _loaded;

  /// Load settings from disk. Call once at app start or when opening settings.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_kNotificationsEnabledKey) ?? true;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsProvider: Error loading settings: $e');
      _notificationsEnabled = true;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Enable or disable app notifications. Persists and notifies listeners.
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabledKey, enabled);
      _notificationsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsProvider: Error saving notifications setting: $e');
    }
  }

  /// Check if notifications are enabled (for code that cannot use the provider).
  static Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kNotificationsEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }
}
