import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:learining_portal/models/message_model.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/firebase_options.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/main.dart';
import 'package:learining_portal/screens/messages/chat.dart';
import 'package:learining_portal/screens/notices/notice_board.dart';
import 'package:provider/provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');

  // Initialize Flutter bindings for background execution
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await localNotifications.initialize(settings: initSettings);

  // Create notification channel for Android
  const androidChannel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications for new messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(androidChannel);

  final chatId = message.data['chatId'] ?? message.data['chat_id'];
  final isNotice = message.data['type'] == 'notice' ||
      message.data['notification_type'] == 'notice' ||
      message.data['notice_id'] != null;

  final String title;
  final String body;
  final String? payload;

  if (isNotice) {
    title = 'Notice';
    body = (message.data['title'] ??
            message.data['notice_title'] ??
            message.notification?.title ??
            message.notification?.body ??
            'New notice')
        .toString();
    payload = 'notice';
  } else {
    title =
        message.notification?.title ?? message.data['title'] ?? 'New message';
    body =
        message.notification?.body ??
        message.data['message'] ??
        message.data['body'] ??
        'You have a new message';
    payload = chatId;
  }

  if (chatId != null || message.notification != null || isNotice) {
    final id = (payload?.hashCode ?? message.hashCode) & 0x7FFFFFFF;
    await localNotifications.show(
      id: id,
      title: title,
      body: body.length > 100 ? '${body.substring(0, 100)}...' : body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages_channel',
          'Messages',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = firestore;

  bool _isInitialized = false;
  String? _currentUserId;
  final Map<String, StreamSubscription> _chatSubscriptions = {};
  String? _currentOpenChatId; // Track which chat screen is currently open

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notification permission');
      } else {
        debugPrint(
          'User declined or has not accepted notification permissions',
        );
        // Continue initialization even without permission
        // FCM token might still be obtainable, and WebSocket will still work
      }

      // Initialize local notifications for Android
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      const androidChannel = AndroidNotificationChannel(
        'messages_channel',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Note: Background message handler is registered in main.dart before runApp()
      // This ensures it works when the app is closed

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      // Use a delay to ensure navigator is ready
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        // Wait for the app to be fully initialized before navigating
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationTap(initialMessage);
          });
        });
      }

      // Listen for token refresh and update in Firestore
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM token refreshed: $newToken');
        if (_currentUserId != null) {
          saveFCMTokenToUser(_currentUserId!, newToken);
        }
      });

      _isInitialized = true;
      debugPrint('Notification service initialized');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  // Get FCM token and save to user document
  Future<String?> getFCMToken() async {
    try {
      // Check if Firebase Messaging is available
      final token = await _firebaseMessaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Token obtained: ${token.substring(0, 20)}...');
        return token;
      } else {
        debugPrint('FCM Token is null or empty');
        return null;
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase error getting FCM token: ${e.code} - ${e.message}');

      // Handle specific error codes
      if (e.code == 'unknown' ||
          e.message?.contains('MISSING_INSTANCEID_SERVICE') == true) {
        debugPrint(
          'FCM Error: Google Play Services may not be available. '
          'This can happen on emulators without Google Play Services or devices without Google Play Store.',
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      // Check if it's the specific error
      if (e.toString().contains('MISSING_INSTANCEID_SERVICE')) {
        debugPrint(
          'FCM Error: MISSING_INSTANCEID_SERVICE - '
          'Google Play Services is required for FCM. '
          'Ensure you are running on a device/emulator with Google Play Services installed.',
        );
      }
      return null;
    }
  }

  // Save FCM token to user document (Firestore and Database)
  Future<void> saveFCMTokenToUser(
    String userId,
    String? token, {
    String? userType,
  }) async {
    if (token == null || userId.isEmpty) return;

    try {
      // Save to Firestore
      await _firestore.collection('user').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM token saved to Firestore for user: $userId');

      // Also save to MySQL database via API
      try {
        if (userType != null) {
          // Use provided user type
          final result = await MessagesChatRepository.saveFCMToken(
            userId: userId,
            userType: userType,
            fcmToken: token,
          );
          if (result['success'] == true) {
            debugPrint(
              'FCM token saved to database for user: $userId (type: $userType)',
            );
          } else {
            debugPrint(
              'Failed to save FCM token to database: ${result['error']}',
            );
          }
        } else {
          // Try both types if user type not provided
          await _saveFCMTokenToDatabase(userId, token);
        }
      } catch (e) {
        debugPrint('Error saving FCM token to database: $e');
        // Don't fail if database save fails - Firestore save succeeded
      }
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  // Save FCM token to MySQL database via API
  Future<void> _saveFCMTokenToDatabase(String userId, String token) async {
    // Try to determine user type - we'll try both and let the API handle it
    // Or you can pass user type if available
    for (final userType in ['staff', 'student']) {
      final result = await MessagesChatRepository.saveFCMToken(
        userId: userId,
        userType: userType,
        fcmToken: token,
      );

      if (result['success'] == true) {
        debugPrint(
          'FCM token saved to database for user: $userId (type: $userType)',
        );
        return; // Success, exit
      }
    }

    debugPrint('Failed to save FCM token to database for user: $userId');
  }

  // Start listening for new messages
  Future<void> startListeningForMessages(String currentUserId) async {
    if (_currentUserId == currentUserId) {
      return; // Already listening
    }

    // Stop previous subscriptions
    stopListeningForMessages();

    _currentUserId = currentUserId;

    try {
      // Get all chats where current user is a participant
      final existingChats1 = await _firestore
          .collection('chats')
          .where('user1Id', isEqualTo: currentUserId)
          .get();

      final existingChats2 = await _firestore
          .collection('chats')
          .where('user2Id', isEqualTo: currentUserId)
          .get();

      // Listen to existing chats
      for (var doc in existingChats1.docs) {
        _listenToChatMessages(doc.id, currentUserId);
      }

      for (var doc in existingChats2.docs) {
        _listenToChatMessages(doc.id, currentUserId);
      }

      // Listen for new chats
      _firestore
          .collection('chats')
          .where('user1Id', isEqualTo: currentUserId)
          .snapshots()
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                _listenToChatMessages(change.doc.id, currentUserId);
              } else if (change.type == DocumentChangeType.removed) {
                _chatSubscriptions[change.doc.id]?.cancel();
                _chatSubscriptions.remove(change.doc.id);
              }
            }
          });

      _firestore
          .collection('chats')
          .where('user2Id', isEqualTo: currentUserId)
          .snapshots()
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                _listenToChatMessages(change.doc.id, currentUserId);
              } else if (change.type == DocumentChangeType.removed) {
                _chatSubscriptions[change.doc.id]?.cancel();
                _chatSubscriptions.remove(change.doc.id);
              }
            }
          });

      debugPrint('Started listening for messages for user: $currentUserId');
    } catch (e) {
      debugPrint('Error starting message listener: $e');
    }
  }

  // Listen to messages in a specific chat
  void _listenToChatMessages(String chatId, String currentUserId) {
    // Cancel existing subscription for this chat if any
    _chatSubscriptions[chatId]?.cancel();

    // Track last message timestamp to avoid duplicate notifications
    DateTime? lastMessageTime;

    _chatSubscriptions[chatId] = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final message = MessageModel.fromFirestore(snapshot.docs.first);

            // Only show notification if:
            // 1. Message is not from current user
            // 2. Message is not read
            // 3. Message is new (different timestamp than last one)
            if (message.senderId != currentUserId &&
                !message.isRead &&
                (lastMessageTime == null ||
                    message.timestamp.isAfter(lastMessageTime!))) {
              lastMessageTime = message.timestamp;
              _showLocalNotification(message, chatId);
            }
          }
        });
  }

  // Handle foreground messages (app open but may not be on chat screen)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    final chatId = message.data['chatId'] ?? message.data['chat_id'];
    final isNotice = message.data['type'] == 'notice' ||
        message.data['notification_type'] == 'notice' ||
        message.data['notice_id'] != null;

    final String title;
    final String body;
    final String? payload;

    if (isNotice) {
      title = 'Notice';
      body = (message.data['title'] ??
              message.data['notice_title'] ??
              message.notification?.title ??
              message.notification?.body ??
              'New notice')
          .toString();
      payload = 'notice';
    } else {
      title =
          message.notification?.title ?? message.data['title'] ?? 'New message';
      body =
          message.notification?.body ??
          message.data['message'] ??
          message.data['body'] ??
          '';
      payload = chatId;
    }

    if (title.isNotEmpty || body.isNotEmpty) {
      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body.length > 100 ? '${body.substring(0, 100)}...' : body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'messages_channel',
            'Messages',
            channelDescription: 'Notifications for new messages',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    }
  }

  // Handle notification tap (when app is in background or terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    final isNotice = message.data['type'] == 'notice' ||
        message.data['notification_type'] == 'notice' ||
        message.data['notice_id'] != null;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (isNotice) {
      _navigateToNoticeBoard(context);
    } else {
      final chatId = message.data['chatId'];
      if (chatId != null) _navigateToChat(chatId);
    }
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    final payload = response.payload;
    final context = navigatorKey.currentContext;
    if (context == null || payload == null) return;
    if (payload == 'notice') {
      _navigateToNoticeBoard(context);
    } else {
      _navigateToChat(payload);
    }
  }

  void _navigateToNoticeBoard(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NoticeBoardScreen(),
        ),
      );
      debugPrint('Navigated to Notice Board');
    } catch (e) {
      debugPrint('Error navigating to notice board: $e');
    }
  }

  // Navigate to chat screen with chatId
  void _navigateToChat(String chatId) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Cannot navigate: Navigator context is null');
      // Retry after a short delay in case the app is still initializing
      Future.delayed(const Duration(milliseconds: 1000), () {
        final retryContext = navigatorKey.currentContext;
        if (retryContext != null) {
          _navigateToChat(chatId);
        }
      });
      return;
    }

    try {
      // Check if we can access Provider to verify authentication
      // If not available, proceed anyway (notifications should only come to authenticated users)
      bool shouldNavigate = true;
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) {
          debugPrint('User not authenticated, skipping navigation');
          shouldNavigate = false;
        }
      } catch (e) {
        // Provider not available, proceed with navigation
        debugPrint('Could not check auth state: $e');
      }

      if (shouldNavigate) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreenWrapper(chatId: chatId),
          ),
        );
        debugPrint('Navigated to chat: $chatId');
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
    }
  }

  // Set the currently open chat (call when chat screen opens)
  void setCurrentOpenChat(String? chatId) {
    _currentOpenChatId = chatId;
    debugPrint('Current open chat set to: $chatId');
  }

  // Clear the currently open chat (call when chat screen closes)
  void clearCurrentOpenChat() {
    _currentOpenChatId = null;
    debugPrint('Current open chat cleared');
  }

  /// Show a local notification when a new message is received via WebSocket
  /// and the user is not currently viewing that chat.
  /// [chatConnectionId] - The chat connection ID (same as chatId used in setCurrentOpenChat)
  /// [senderId] - The sender's user ID (for fetching name from Firestore)
  /// [messageText] - The message content to show in the notification
  Future<void> showNotificationForWebSocketMessage(
    String chatConnectionId,
    String senderId,
    String messageText,
  ) async {
    // Don't show if this chat is currently open
    if (_currentOpenChatId == chatConnectionId) {
      debugPrint(
        'Skipping WebSocket notification for currently open chat: $chatConnectionId',
      );
      return;
    }

    try {
      String senderName = 'New message';
      try {
        final senderDoc = await _firestore
            .collection('user')
            .doc(senderId)
            .get();
        if (senderDoc.exists) {
          final sender = UserModel.fromFirestore(senderDoc);
          senderName = sender.fullName;
        }
      } catch (e) {
        debugPrint('Could not fetch sender name for notification: $e');
      }

      final body = messageText.length > 100
          ? '${messageText.substring(0, 100)}...'
          : messageText;

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        id: chatConnectionId.hashCode,
        title: senderName,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: chatConnectionId,
      );

      debugPrint(
        'Local notification shown for WebSocket message in chat $chatConnectionId',
      );
    } catch (e) {
      debugPrint('Error showing WebSocket message notification: $e');
    }
  }

  // Show local notification for new message
  Future<void> _showLocalNotification(
    MessageModel message,
    String chatId,
  ) async {
    // Don't show notification if this chat is currently open
    if (_currentOpenChatId == chatId) {
      debugPrint('Skipping notification for currently open chat: $chatId');
      return;
    }

    try {
      // Fetch sender info
      final senderDoc = await _firestore
          .collection('user')
          .doc(message.senderId)
          .get();
      String senderName = 'Someone';

      if (senderDoc.exists) {
        final sender = UserModel.fromFirestore(senderDoc);
        senderName = sender.fullName;
      }

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: message.messageId.hashCode,
        title: senderName,
        body: message.text,
        notificationDetails: details,
        payload: chatId,
      );

      debugPrint('Local notification shown for message from $senderName');
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // Stop listening for messages
  void stopListeningForMessages() {
    for (var subscription in _chatSubscriptions.values) {
      subscription.cancel();
    }
    _chatSubscriptions.clear();
    _currentUserId = null;
    debugPrint('Stopped listening for messages');
  }

  // Send FCM notification to recipient (works on Spark plan - no Cloud Functions needed)
  // Note: You'll need to get your FCM server key from Firebase Console:
  // Project Settings > Cloud Messaging > Server key
  Future<void> sendFCMNotification({
    required String recipientUserId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await _firestore
          .collection('user')
          .doc(recipientUserId)
          .get();
      if (!recipientDoc.exists) {
        debugPrint('Recipient not found: $recipientUserId');
        return;
      }

      final recipientData = recipientDoc.data();
      final fcmToken = recipientData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('No FCM token found for recipient: $recipientUserId');
        return;
      }

      // Get FCM server key from Firestore config
      // First, try to get from Firestore
      final configDoc = await _firestore.collection('config').doc('fcm').get();
      String? serverKey = configDoc.data()?['serverKey'] as String?;

      // If not in Firestore, try to get from a constants file (for development)
      // You can create lib/configs/fcm_config.dart with: class FCMConfig { static const String serverKey = 'YOUR_KEY'; }
      if (serverKey == null || serverKey.isEmpty) {
        try {
          // Try to import from config file if it exists
          // This is a fallback - prefer storing in Firestore
          // Uncomment and create the file if needed:
          // final fcmConfig = await import('package:learining_portal/configs/fcm_config.dart');
          // serverKey = FCMConfig.serverKey;
        } catch (e) {
          // Config file doesn't exist, that's okay
        }
      }

      if (serverKey == null || serverKey.isEmpty) {
        debugPrint(
          'FCM server key not configured. Please:\n'
          '1. Enable "Cloud Messaging API (Legacy)" in Firebase Console\n'
          '2. Get the Server key from Project Settings > Cloud Messaging\n'
          '3. Add it to Firestore: config/fcm/serverKey\n'
          'See FCM_SETUP.md for detailed instructions.',
        );
        return;
      }

      // Send FCM notification via REST API
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      final body = jsonEncode({
        'to': fcmToken,
        'notification': {
          'title': senderName,
          'body': messageText,
          'sound': 'default',
        },
        'data': {
          'chatId': chatId,
          'type': 'message',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'priority': 'high',
          'notification': {'channelId': 'messages_channel', 'sound': 'default'},
        },
        'apns': {
          'payload': {
            'aps': {'sound': 'default', 'badge': 1},
          },
        },
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        debugPrint('FCM notification sent successfully to $recipientUserId');
      } else {
        debugPrint(
          'Failed to send FCM notification: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }

  // Dispose
  void dispose() {
    stopListeningForMessages();
  }
}
