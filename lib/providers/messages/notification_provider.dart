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

      // Get and save FCM token (non-blocking - app works even if FCM fails)
      if (authProvider.isAuthenticated && authProvider.currentUserId != null) {
        try {
          final token = await _notificationService.getFCMToken();
          if (token != null) {
            // Get user type for database save
            String? userType;
            if (authProvider.userType != null) {
              final type = authProvider.userType!;
              userType = (type == UserType.teacher || type == UserType.admin)
                  ? 'staff'
                  : 'student';
            }
            await _notificationService.saveFCMTokenToUser(
              authProvider.currentUserId!,
              token,
              userType: userType,
            );
          } else {
            debugPrint(
              'NotificationProvider: FCM token not available. '
              'Push notifications will not work, but WebSocket messaging will still function.',
            );
          }
        } catch (e) {
          debugPrint(
            'NotificationProvider: Error getting FCM token: $e. '
            'App will continue to work with WebSocket messaging.',
          );
          // Don't throw - app should work even without FCM
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
      // Save FCM token (non-blocking - app works even if FCM fails)
      try {
        final token = await _notificationService.getFCMToken();
        if (token != null) {
          // Get user type for database save
          String? userType;
          if (authProvider.userType != null) {
            final type = authProvider.userType!;
            userType = (type == UserType.teacher || type == UserType.admin)
                ? 'staff'
                : 'student';
          }
          await _notificationService.saveFCMTokenToUser(
            authProvider.currentUserId!,
            token,
            userType: userType,
          );
        } else {
          debugPrint(
            'NotificationProvider: FCM token not available. '
            'Push notifications will not work, but WebSocket messaging will still function.',
          );
        }
      } catch (e) {
        debugPrint(
          'NotificationProvider: Error getting FCM token: $e. '
          'App will continue to work with WebSocket messaging.',
        );
        // Don't throw - app should work even without FCM
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
