import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth_provider.dart';
import '../../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  AuthProvider? _authProvider;
  bool _isInitialized = false;

  // Initialize notifications
  Future<void> initialize(AuthProvider authProvider) async {
    if (_isInitialized) return;

    _authProvider = authProvider;
    
    try {
      // Initialize notification service
      await _notificationService.initialize();

      // Get and save FCM token
      if (authProvider.isAuthenticated && authProvider.currentUserId != null) {
        final token = await _notificationService.getFCMToken();
        if (token != null) {
          await _notificationService.saveFCMTokenToUser(
            authProvider.currentUserId!,
            token,
          );
        }

        // Start listening for messages
        await _notificationService.startListeningForMessages(
          authProvider.currentUserId!,
        );
      }

      _isInitialized = true;
      debugPrint('Notification provider initialized');
    } catch (e) {
      debugPrint('Error initializing notification provider: $e');
    }
  }

  // Update when auth state changes
  Future<void> onAuthStateChanged(AuthProvider authProvider) async {
    _authProvider = authProvider;

    if (authProvider.isAuthenticated && authProvider.currentUserId != null) {
      // Save FCM token
      final token = await _notificationService.getFCMToken();
      if (token != null) {
        await _notificationService.saveFCMTokenToUser(
          authProvider.currentUserId!,
          token,
        );
      }

      // Start listening for messages
      await _notificationService.startListeningForMessages(
        authProvider.currentUserId!,
      );
    } else {
      // Stop listening when logged out
      _notificationService.stopListeningForMessages();
    }
  }

  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}
