import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../network/domain/messages_chat_repository.dart';

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
        await _saveFCMTokenToDatabaseWithRetry(authProvider);

        // Start listening for messages
        await _notificationService.startListeningForMessages(
          authProvider.currentUserId!,
          userType: authProvider.userType,
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
      // Save FCM token (ensures DB has token for push when app is closed)
      await _saveFCMTokenToDatabaseWithRetry(authProvider);

      // Start listening for messages
      await _notificationService.startListeningForMessages(
        authProvider.currentUserId!,
        userType: authProvider.userType,
      );
    } else {
      // Stop listening when logged out
      _notificationService.stopListeningForMessages();
    }
  }

  /// Show a local notification when a new message is received (e.g. via WebSocket)
  /// and the user is not currently viewing that chat.
  void showNotificationForIncomingMessage(Map<String, dynamic> messageData) {
    final chatConnectionId =
        messageData['chat_connection_id']?.toString() ??
        messageData['chatId']?.toString();
    final senderId = messageData['sender_id']?.toString();
    final message = messageData['message']?.toString();

    if (chatConnectionId == null ||
        chatConnectionId.isEmpty ||
        message == null ||
        message.isEmpty) {
      debugPrint('NotificationProvider: Invalid message data for notification');
      return;
    }

    _notificationService.showNotificationForWebSocketMessage(
      chatConnectionId,
      senderId ?? 'unknown',
      message,
      senderDisplayName: messageData['sender_display_name']?.toString(),
    );
  }

  /// Save FCM token to database with retries (handles race where chat user row isn't created yet).
  /// Call this on init and when app resumes so the server always has the token for push when app is closed.
  Future<void> _saveFCMTokenToDatabaseWithRetry(
    AuthProvider authProvider,
  ) async {
    final userId = authProvider.currentUserId;
    if (userId == null) return;

    // For MySQL/fl_chat_users use API id (guardian = parent id) so FCM lookup finds the row
    final apiUserId = authProvider.apiUserIdForChat ?? userId;

    final typeForApi = authProvider.userType != null
        ? UserModel.userTypeToApiString(authProvider.userType!)
        : 'student';

    Future<bool> trySaveToDatabase() async {
      try {
        final token = await _notificationService.getFCMToken();
        if (token == null) {
          debugPrint(
            'NotificationProvider: FCM token not available. '
            'Push when app is closed will not work until token is obtained.',
          );
          return false;
        }
        // Save to Firestore (once) using document id
        await _notificationService.saveFCMTokenToUser(
          userId,
          token,
          userType: typeForApi,
        );
        // Save to MySQL (so backend can send FCM) using API id (parent_id for guardian)
        final result = await MessagesChatRepository.saveFCMToken(
          userId: apiUserId,
          userType: typeForApi,
          fcmToken: token,
        );
        if (result['success'] == true) {
          debugPrint('NotificationProvider: FCM token saved to database.');
          return true;
        }
        final error = result['error']?.toString() ?? '';
        if (error.toLowerCase().contains('not found') ||
            error.toLowerCase().contains('chat user')) {
          debugPrint(
            'NotificationProvider: Chat user not ready, will retry: $error',
          );
        } else {
          debugPrint('NotificationProvider: FCM token save failed: $error');
        }
        return false;
      } catch (e) {
        debugPrint(
          'NotificationProvider: Error saving FCM token: $e. '
          'App will continue; push when app is closed may not work.',
        );
        return false;
      }
    }

    await trySaveToDatabase();
    // Retry after delay (chat user row may be created after login)
    Future.delayed(const Duration(seconds: 3), () async {
      await trySaveToDatabase();
    });
    Future.delayed(const Duration(seconds: 8), () async {
      await trySaveToDatabase();
    });
  }

  /// Call when app comes to foreground so the server has the latest FCM token for push when app is closed.
  Future<void> refreshFCMTokenInDatabase(AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated || authProvider.currentUserId == null) {
      return;
    }
    await _saveFCMTokenToDatabaseWithRetry(authProvider);
  }

  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}
