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
import 'package:learining_portal/providers/profile/settings_provider.dart';
import 'package:learining_portal/utils/chat_notification_label.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/main.dart';
import 'package:learining_portal/screens/feedback/guardian_daily_feedback_screen.dart';
import 'package:learining_portal/screens/messages/chat.dart';
import 'package:learining_portal/screens/notices/notice_board.dart';
import 'package:learining_portal/screens/tickets/ticket_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Respect user preference: do not show notifications when disabled
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('notifications_enabled') == false) {
    return;
  }

  final chatId = message.data['chatId'] ?? message.data['chat_id'];
  final isDailyFeedback =
      message.data['type'] == 'daily_feedback' ||
      message.data['notification_type'] == 'daily_feedback';
  final bgNoticeRaw = message.data['notice_id'];
  final bgHasNoticeId = bgNoticeRaw != null &&
      bgNoticeRaw.toString().trim().isNotEmpty;
  final isNotice =
      !isDailyFeedback &&
      (message.data['type'] == 'notice' ||
          message.data['notification_type'] == 'notice' ||
          bgHasNoticeId);

  // For notices: only show our notification when the message is data-only (no
  // FCM "notification" block). Otherwise the OS shows one from the notification
  // block and we would show a second, causing two notifications when app is closed.
  final isDataOnlyNotice = isNotice && message.notification == null;

  // For daily_feedback: same as notices — if the server sent a "notification" block,
  // the system already shows it when app is in background; don't show a second one.
  final isDataOnlyDailyFeedback = isDailyFeedback && message.notification == null;
  final isTicketCreated = !isDailyFeedback && !isNotice && (message.data['type'] == 'ticket_created');
  final isTicketReply = !isDailyFeedback && !isNotice && (message.data['type'] == 'ticket_reply');
  final hasTicketId = (message.data['ticket_id']?.toString() ?? '').isNotEmpty;
  final isDataOnlyTicket = (isTicketCreated || isTicketReply) && message.notification == null && hasTicketId;
  // Chat: if FCM includes a "notification" block, the OS already shows one — do not also show local (duplicate).
  final isChatLike =
      !isDailyFeedback && !isNotice && !isTicketCreated && !isTicketReply;
  final isDataOnlyChat = isChatLike &&
      chatId != null &&
      chatId.toString().isNotEmpty &&
      message.notification == null;

  late String title;
  late String body;
  final String? payload;

  if (isDailyFeedback) {
    title = 'Daily Feedback';
    body =
        message.notification?.body ??
        message.data['body'] ??
        'New feedback for your child.';
    payload = 'daily_feedback';
  } else if (isNotice) {
    title = 'Notice';
    body =
        (message.data['title'] ??
                message.data['notice_title'] ??
                message.notification?.title ??
                message.notification?.body ??
                'New notice')
            .toString();
    payload = 'notice';
  } else if (isTicketCreated || isTicketReply) {
    title = message.data['title']?.toString() ?? (isTicketCreated ? 'New support ticket' : 'New reply on ticket');
    body = message.data['body']?.toString() ?? message.data['subject']?.toString() ?? message.data['message']?.toString() ?? (isTicketCreated ? 'A new ticket was submitted.' : 'You have a new reply.');
    final ticketId = message.data['ticket_id']?.toString();
    payload = (ticketId != null && ticketId.isNotEmpty) ? 'ticket_$ticketId' : null;
  } else {
    title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'New message';
    body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        message.data['message']?.toString() ??
        'You have a new message';
    payload = chatId?.toString();
  }

  if (isDataOnlyChat) {
    final prefs = await SharedPreferences.getInstance();
    final viewerIsAdmin = prefs.getString(prefsKeyUserType) == 'admin';
    final senderIdForTitle = message.data['senderId']?.toString() ?? '';
    final actualStaff = message.data['actual_sender_staff_id']?.toString();
    final nameHint = message.data['title']?.toString() ??
        message.notification?.title?.toString();
    title = chatNotificationSenderTitle(
      viewerIsAdmin: viewerIsAdmin,
      senderId: senderIdForTitle,
      actualSenderStaffId: actualStaff,
      senderDisplayNameOrTitleFromPayload: nameHint,
    );
  }

  // Only synthesize a local notification when the payload is data-only (no FCM notification block).
  // Otherwise the system tray already shows one and we would duplicate (e.g. legacy sendNotification).
  if (isDataOnlyDailyFeedback ||
      isDataOnlyTicket ||
      isDataOnlyNotice ||
      isDataOnlyChat) {
    if (isDataOnlyChat) {
      final mid = message.data['message_id']?.toString();
      if (!NotificationService.tryClaimChatMessageNotificationId(mid)) {
        return;
      }
    }
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

  /// Avoids double alerts when the same chat message is delivered via WebSocket and FCM (same fl_chat_messages.id).
  static final Map<String, DateTime> _chatMessageNotificationDedup = {};
  static const Duration _chatDedupTtl = Duration(seconds: 90);

  /// Returns false if we already showed (or claimed) this [messageId] recently.
  static bool tryClaimChatMessageNotificationId(String? messageId) {
    if (messageId == null || messageId.isEmpty) return true;
    final now = DateTime.now();
    _chatMessageNotificationDedup.removeWhere(
      (_, t) => now.difference(t) > _chatDedupTtl,
    );
    if (_chatMessageNotificationDedup.containsKey(messageId)) {
      debugPrint('NotificationService: dedup skip chat message_id=$messageId');
      return false;
    }
    _chatMessageNotificationDedup[messageId] = now;
    return true;
  }

  /// Undo [tryClaimChatMessageNotificationId] if [show] failed after claiming.
  static void releaseChatMessageNotificationId(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;
    _chatMessageNotificationDedup.remove(messageId);
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = firestore;

  bool _isInitialized = false;
  String? _currentUserId;
  /// Guardian/student/teacher API id for fl_chat_users (parent_id, etc.). Matches [AuthProvider.apiUserIdForChat].
  String? _apiUserIdForChat;
  /// Used for foreground FCM: admins get WS + FCM for Support inbox; suppress duplicate local from FCM.
  UserType? _messageListenerUserType;
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
    if (!await SettingsProvider.areNotificationsEnabled()) return;

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

  // Save FCM token to MySQL database via API (try each UserType until one matches fl_chat_users row)
  Future<void> _saveFCMTokenToDatabase(String userId, String token) async {
    const userTypes = ['student', 'guardian', 'teacher', 'admin'];
    for (final userType in userTypes) {
      final result = await MessagesChatRepository.saveFCMToken(
        userId: userId,
        userType: userType,
        fcmToken: token,
      );
      if (result['success'] == true) {
        debugPrint(
          'FCM token saved to database for user: $userId (type: $userType)',
        );
        return;
      }
    }
    debugPrint('Failed to save FCM token to database for user: $userId');
  }

  // Start listening for new messages
  Future<void> startListeningForMessages(
    String currentUserId, {
    UserType? userType,
    String? apiUserIdForChat,
  }) async {
    if (_currentUserId == currentUserId &&
        _messageListenerUserType == userType &&
        _apiUserIdForChat == apiUserIdForChat) {
      return; // Already listening
    }

    // Stop previous subscriptions
    stopListeningForMessages();

    _currentUserId = currentUserId;
    _apiUserIdForChat = apiUserIdForChat;
    _messageListenerUserType = userType;

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
  void _handleForegroundMessage(RemoteMessage message) async {
    if (!await SettingsProvider.areNotificationsEnabled()) return;
    debugPrint('Received foreground message: ${message.messageId}');

    final chatId = message.data['chatId'] ?? message.data['chat_id'];
    final isDailyFeedback =
        message.data['type'] == 'daily_feedback' ||
        message.data['notification_type'] == 'daily_feedback';
    final noticeIdRaw = message.data['notice_id'];
    final hasNoticeId = noticeIdRaw != null &&
        noticeIdRaw.toString().trim().isNotEmpty;
    final isNotice =
        !isDailyFeedback &&
        (message.data['type'] == 'notice' ||
            message.data['notification_type'] == 'notice' ||
            hasNoticeId);
    final isTicketCreated = !isDailyFeedback && !isNotice && (message.data['type'] == 'ticket_created');
    final isTicketReply = !isDailyFeedback && !isNotice && (message.data['type'] == 'ticket_reply');

    // Same "own message" rules as main.dart WebSocket handler (Firebase uid + API chat id for guardians).
    // Never treat Support virtual sender (senderId "0") as self — it would match a bad/missing firebase id of "0".
    if (!isNotice && !isDailyFeedback && !isTicketCreated && !isTicketReply) {
      final senderId = message.data['senderId']?.toString();
      if (senderId != null && senderId.trim() != supportUserId) {
        final matchesFirebase =
            _currentUserId != null && senderId == _currentUserId;
        final matchesApi = _apiUserIdForChat != null &&
            _apiUserIdForChat!.isNotEmpty &&
            senderId == _apiUserIdForChat;
        if (matchesFirebase || matchesApi) {
          debugPrint(
            'Foreground FCM: skip own message senderId=$senderId '
            '(firebase=$_currentUserId apiChat=$_apiUserIdForChat)',
          );
          return;
        }
      }
    }

    final String title;
    final String body;
    final String? payload;

    if (isDailyFeedback) {
      title = 'Daily Feedback';
      body =
          message.notification?.body ??
          message.data['body'] ??
          'New feedback for your child.';
      payload = 'daily_feedback';
    } else if (isNotice) {
      title = 'Notice';
      body =
          (message.data['title'] ??
                  message.data['notice_title'] ??
                  message.notification?.title ??
                  message.notification?.body ??
                  'New notice')
              .toString();
      payload = 'notice';
    } else if (isTicketCreated || isTicketReply) {
      title = message.data['title']?.toString() ?? (isTicketCreated ? 'New support ticket' : 'New reply on ticket');
      body = message.data['body']?.toString() ?? message.data['subject']?.toString() ?? message.data['message']?.toString() ?? (isTicketCreated ? 'A new ticket was submitted.' : 'You have a new reply.');
      final ticketId = message.data['ticket_id']?.toString();
      payload = (ticketId != null && ticketId.isNotEmpty) ? 'ticket_$ticketId' : null;
    } else {
      // Chat: server sends data-only FCM even when WebSocket delivered (see websocket_server.php).
      // Foreground shows a local notification; admins skip here (inbox uses WebSocket).
      if (_messageListenerUserType == UserType.admin) {
        return;
      }
      final chatIdStr = chatId?.toString().trim();
      final bodyText = () {
        final fromData = message.data['body']?.toString() ??
            message.data['message']?.toString();
        if (fromData != null && fromData.trim().isNotEmpty) {
          return fromData;
        }
        final fromNotif = message.notification?.body;
        if (fromNotif != null && fromNotif.trim().isNotEmpty) {
          return fromNotif;
        }
        final t = message.data['message_type']?.toString();
        if (t == 'image') return 'Photo';
        if (t == 'document') return 'Document';
        // Match push/tray: notification body may exist when data fields are sparse (iOS foreground).
        final fromNotifTitle = message.notification?.title;
        if (fromNotifTitle != null && fromNotifTitle.isNotEmpty) {
          return message.notification?.body?.trim().isNotEmpty == true
              ? message.notification!.body!
              : 'New message';
        }
        return 'New message';
      }();
      if (chatIdStr == null || chatIdStr.isEmpty) {
        debugPrint('Foreground FCM chat: missing chatId, data=${message.data}');
        return;
      }
      final senderIdForNotif =
          message.data['senderId']?.toString() ?? 'unknown';
      final nameHint = message.data['title']?.toString() ??
          message.notification?.title;
      await showNotificationForWebSocketMessage(
        chatIdStr,
        senderIdForNotif,
        bodyText,
        senderDisplayName: nameHint,
        actualSenderStaffId:
            message.data['actual_sender_staff_id']?.toString(),
        serverMessageId: message.data['message_id']?.toString(),
      );
      return;
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
    final isDailyFeedback =
        message.data['type'] == 'daily_feedback' ||
        message.data['notification_type'] == 'daily_feedback';
    final isNotice =
        !isDailyFeedback &&
        (message.data['type'] == 'notice' ||
            message.data['notification_type'] == 'notice' ||
            message.data['notice_id'] != null);
    final isTicket = !isDailyFeedback && !isNotice &&
        (message.data['type'] == 'ticket_created' || message.data['type'] == 'ticket_reply');
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (isDailyFeedback) {
      _navigateToDailyFeedback(context);
    } else if (isNotice) {
      _navigateToNoticeBoard(context);
    } else if (isTicket) {
      final ticketIdStr = message.data['ticket_id']?.toString();
      final subject = message.data['subject']?.toString() ?? 'Ticket';
      if (ticketIdStr != null && ticketIdStr.isNotEmpty) {
        final ticketId = int.tryParse(ticketIdStr);
        if (ticketId != null) _navigateToTicket(context, ticketId, subject);
      }
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
    if (payload == 'daily_feedback') {
      _navigateToDailyFeedback(context);
    } else if (payload == 'notice') {
      _navigateToNoticeBoard(context);
    } else if (payload.startsWith('ticket_')) {
      final idStr = payload.substring(7);
      final ticketId = int.tryParse(idStr);
      if (ticketId != null) _navigateToTicket(context, ticketId, 'Ticket');
    } else {
      _navigateToChat(payload);
    }
  }

  void _navigateToTicket(BuildContext context, int ticketId, String subject) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TicketDetailScreen(
            ticketId: ticketId,
            ticketSubject: subject,
          ),
        ),
      );
      debugPrint('Navigated to ticket: $ticketId');
    } catch (e) {
      debugPrint('Error navigating to ticket: $e');
    }
  }

  void _navigateToNoticeBoard(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NoticeBoardScreen()),
      );
      debugPrint('Navigated to Notice Board');
    } catch (e) {
      debugPrint('Error navigating to notice board: $e');
    }
  }

  void _navigateToDailyFeedback(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GuardianDailyFeedbackScreen(),
        ),
      );
      debugPrint('Navigated to Daily Feedback');
    } catch (e) {
      debugPrint('Error navigating to daily feedback: $e');
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
    final s = chatId?.toString().trim();
    _currentOpenChatId = (s != null && s.isNotEmpty) ? s : null;
    debugPrint('Current open chat set to: $_currentOpenChatId');
  }

  // Clear the currently open chat (call when chat screen closes)
  void clearCurrentOpenChat() {
    _currentOpenChatId = null;
    debugPrint('Current open chat cleared');
  }

  bool _isOpenChatConnection(String chatConnectionId) {
    final open = _currentOpenChatId;
    if (open == null || open.isEmpty) return false;
    return open == chatConnectionId.toString().trim();
  }

  /// True while [ChatScreen] has registered an open thread (WebSocket is owned by [ChatProvider]).
  bool get hasOpenChatSession =>
      _currentOpenChatId != null && _currentOpenChatId!.isNotEmpty;

  Future<String> _resolveChatNotificationTitleAsync({
    required bool viewerIsAdmin,
    required String senderId,
    String? actualSenderStaffId,
    String? senderDisplayNameFromPayload,
  }) async {
    final initial = chatNotificationSenderTitle(
      viewerIsAdmin: viewerIsAdmin,
      senderId: senderId,
      actualSenderStaffId: actualSenderStaffId,
      senderDisplayNameOrTitleFromPayload: senderDisplayNameFromPayload,
    );
    if (initial != 'New message') return initial;
    final sid = senderId.trim();
    if (sid.isEmpty || sid == supportUserId) return initial;
    try {
      final senderDoc =
          await _firestore.collection('user').doc(senderId).get();
      if (senderDoc.exists) {
        return UserModel.fromFirestore(senderDoc).fullName;
      }
    } catch (e) {
      debugPrint('Could not fetch sender name for notification: $e');
    }
    return 'New message';
  }

  /// Show a local notification when a new message is received via WebSocket
  /// and the user is not currently viewing that chat.
  /// [chatConnectionId] - The chat connection ID (same as chatId used in setCurrentOpenChat)
  /// [senderId] - The sender's user ID (for fetching name from Firestore)
  /// [messageText] - The message content to show in the notification
  /// [serverMessageId] - fl_chat_messages id when known (dedup with FCM).
  Future<void> showNotificationForWebSocketMessage(
    String chatConnectionId,
    String senderId,
    String messageText, {
    String? senderDisplayName,
    String? actualSenderStaffId,
    String? serverMessageId,
  }) async {
    if (!await SettingsProvider.areNotificationsEnabled()) return;
    // Don't show if this chat is currently open (normalize id like FCM data)
    if (_isOpenChatConnection(chatConnectionId)) {
      debugPrint(
        'Skipping WebSocket notification for currently open chat: $chatConnectionId',
      );
      return;
    }
    if (!tryClaimChatMessageNotificationId(serverMessageId)) {
      return;
    }

    try {
      final viewerIsAdmin = _messageListenerUserType == UserType.admin;
      final senderName = await _resolveChatNotificationTitleAsync(
        viewerIsAdmin: viewerIsAdmin,
        senderId: senderId,
        actualSenderStaffId: actualSenderStaffId,
        senderDisplayNameFromPayload: senderDisplayName,
      );

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

      final notifId =
          ((serverMessageId ?? chatConnectionId).hashCode) & 0x7FFFFFFF;
      await _localNotifications.show(
        id: notifId,
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
      releaseChatMessageNotificationId(serverMessageId);
      debugPrint('Error showing WebSocket message notification: $e');
    }
  }

  // Show local notification for new message
  Future<void> _showLocalNotification(
    MessageModel message,
    String chatId,
  ) async {
    if (!await SettingsProvider.areNotificationsEnabled()) return;
    // Don't show notification if this chat is currently open
    if (_isOpenChatConnection(chatId)) {
      debugPrint('Skipping notification for currently open chat: $chatId');
      return;
    }

    try {
      final viewerIsAdmin = _messageListenerUserType == UserType.admin;
      final senderName = await _resolveChatNotificationTitleAsync(
        viewerIsAdmin: viewerIsAdmin,
        senderId: message.senderId,
        actualSenderStaffId: message.actualSenderId,
        senderDisplayNameFromPayload: message.senderDisplayName,
      );

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
    _apiUserIdForChat = null;
    _messageListenerUserType = null;
    debugPrint('Stopped listening for messages');
  }

  /// Call on logout (all user types). Clears session and deletes FCM token
  /// so a new token is generated on next login.
  Future<void> clearSessionOnLogout() async {
    stopListeningForMessages();
    _chatMessageNotificationDedup.clear();
    try {
      await _firebaseMessaging.deleteToken();
      debugPrint(
        'FCM token deleted on logout; new token will be generated on next login',
      );
    } catch (e) {
      debugPrint('Error deleting FCM token on logout: $e');
    }
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
