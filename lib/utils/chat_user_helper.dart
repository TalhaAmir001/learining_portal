import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/web_socket_client.dart';

/// Helper class to create chat user entries in the database
/// This is used after user login to ensure they exist in fl_chat_users table
class ChatUserHelper {
  /// Create a chat user entry via WebSocket
  ///
  /// [userId] - The user ID (staff_id or student_id from API)
  /// [userType] - The user type ('staff' or 'student')
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> createChatUserAfterLogin({
    required String userId,
    required String userType,
  }) async {
    try {
      debugPrint(
        'ChatUserHelper: Creating chat user entry for userId: $userId, userType: $userType',
      );

      // Create WebSocket client
      final wsClient = WebSocketClient();

      // Set up a completer to wait for the response
      final completer = Completer<bool>();

      // Set up callback for chat user creation
      // wsClient.onChatUserCreated = (data) {
      //   debugPrint(
      //     'ChatUserHelper: onChatUserCreated callback triggered with data: $data',
      //   );
      //   final status = data['status'] as String?;
      //   final chatUserId = data['chat_user_id'];
      //   final isNew = data['is_new'] as bool? ?? false;
      //
      //   debugPrint(
      //     'ChatUserHelper: Parsed - status: $status, chatUserId: $chatUserId, isNew: $isNew',
      //   );
      //
      //   if (status == 'success' && chatUserId != null) {
      //     debugPrint(
      //       'ChatUserHelper: Chat user created successfully. ID: $chatUserId, is_new: $isNew',
      //     );
      //     if (!completer.isCompleted) {
      //       completer.complete(true);
      //     }
      //   } else {
      //     debugPrint(
      //       'ChatUserHelper: Failed to create chat user - status: $status, chatUserId: $chatUserId',
      //     );
      //     if (!completer.isCompleted) {
      //       completer.complete(false);
      //     }
      //   }
      // };

      // Set up error callback to handle server errors
      wsClient.onError = (error) {
        debugPrint('ChatUserHelper: WebSocket error: $error');
        // If it's a chat_user related error, complete the completer
        if (error.contains('chat_user') ||
            error.contains('create_chat_user') ||
            error.contains('Failed to create')) {
          debugPrint(
            'ChatUserHelper: Chat user creation error, completing completer',
          );
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        } else if (!error.contains('Connection failed') &&
            !error.contains('Not connected')) {
          // Other errors after connection should also complete the completer
          debugPrint('ChatUserHelper: Completing completer with error: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      };

      // Connect to WebSocket
      final connected = await wsClient.connect(
        userId: userId,
        userType: userType,
        autoReconnect: false, // Don't auto-reconnect for one-time operation
      );

      if (!connected) {
        debugPrint('ChatUserHelper: Failed to connect to WebSocket');
        wsClient.dispose();
        return false;
      }

      // Connection is now confirmed, we can send the create_chat_user request
      debugPrint(
        'ChatUserHelper: Connection confirmed, sending create_chat_user request',
      );

      // Send create chat user request
      debugPrint('ChatUserHelper: About to send create_chat_user request');
      debugPrint(
        'ChatUserHelper: Connection state before sending - isConnected: ${wsClient.isConnected}',
      );

      // Add a small delay to ensure connection is stable
      await Future.delayed(const Duration(milliseconds: 100));

      // wsClient.createChatUser(userId: userId, userType: userType);
      debugPrint(
        'ChatUserHelper: create_chat_user request sent, waiting for response...',
      );
      debugPrint(
        'ChatUserHelper: Connection state after sending - isConnected: ${wsClient.isConnected}',
      );

      // Wait for response with timeout
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 15), // Increased timeout to 15 seconds
          onTimeout: () {
            debugPrint(
              'ChatUserHelper: Timeout waiting for chat user creation after 15 seconds',
            );
            debugPrint(
              'ChatUserHelper: Connection state - isConnected: ${wsClient.isConnected}',
            );
            return false;
          },
        );

        // Disconnect and cleanup
        wsClient.dispose();

        return result;
      } catch (e) {
        debugPrint('ChatUserHelper: Error creating chat user: $e');
        wsClient.dispose();
        return false;
      }
    } catch (e) {
      debugPrint('ChatUserHelper: Exception creating chat user: $e');
      return false;
    }
  }
}
