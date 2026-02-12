import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/models/message_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/utils/web_socket_client.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';

class ChatProvider with ChangeNotifier {
  WebSocketClient? _wsClient;
  String? _currentUserId;
  String? _currentUserType; // 'staff' or 'student'
  String? _currentUserApiId; // The actual staff_id or student_id from API

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _chatConnectionId;
  bool _isConnected = false;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get chatId => _chatConnectionId;
  bool get isConnected => _isConnected;

  // Get current user ID from AuthProvider
  String? getCurrentUserId(AuthProvider? authProvider) {
    if (authProvider != null) {
      return authProvider.currentUserId;
    }
    return _currentUserId;
  }

  // Set current user ID (can be called when provider is initialized)
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  // Get user type for WebSocket ('staff' or 'student')
  String _getUserTypeForWebSocket(AuthProvider? authProvider) {
    if (authProvider?.userType != null) {
      final userType = authProvider!.userType!;
      // Map app UserType to WebSocket user_type
      // staff = teacher/admin, student = student/guardian
      if (userType == UserType.teacher || userType == UserType.admin) {
        return 'staff';
      } else {
        return 'student';
      }
    }
    return _currentUserType ?? 'staff';
  }

  // Get API user ID (staff_id or student_id) from AuthProvider
  // The uid in UserModel is the actual API ID (id from admin/student API response)
  Future<String?> _getApiUserId(AuthProvider? authProvider) async {
    if (authProvider?.currentUser != null) {
      // The uid field in UserModel is the actual API ID
      // For admin/teacher: it's result.id from AdminDataModel
      // For student/guardian: it's result.id from UserDataModel
      return authProvider!.currentUser!.uid;
    }
    return _currentUserApiId;
  }

  @override
  void dispose() {
    _wsClient?.dispose();
    super.dispose();
  }

  // Initialize WebSocket connection
  Future<void> _initializeWebSocket(AuthProvider? authProvider) async {
    // If already connected with the same user, don't reconnect
    final apiUserId = await _getApiUserId(authProvider);
    if (apiUserId == null) {
      debugPrint('ChatProvider: Cannot initialize WebSocket - no API user ID');
      return;
    }

    final userType = _getUserTypeForWebSocket(authProvider);
    _currentUserApiId = apiUserId;
    _currentUserType = userType;

    // If WebSocket client already exists and connected with same user, skip
    if (_wsClient != null &&
        _wsClient!.isConnected &&
        _wsClient!.userId == apiUserId) {
      debugPrint(
        'ChatProvider: WebSocket already connected for user $apiUserId',
      );
      _isConnected = true;
      return;
    }

    // Dispose existing client if user changed
    if (_wsClient != null) {
      _wsClient!.dispose();
    }

    // Create new WebSocket client
    _wsClient = WebSocketClient();

    // Set up callbacks
    _wsClient!.onConnected = (data) {
      debugPrint('ChatProvider: WebSocket connected');
      _isConnected = true;
      notifyListeners();
    };

    _wsClient!.onNewMessage = (data) {
      debugPrint('ChatProvider: New message received via WebSocket');
      _handleNewMessage(data);
    };

    _wsClient!.onMessageSent = (data) {
      debugPrint('ChatProvider: Message sent confirmation');
      final messageId = data['message_id']?.toString();
      final senderDisplayName = data['sender_display_name'] as String?;
      final actualSenderId = data['actual_sender_staff_id']?.toString();
      if (messageId != null) {
        // Update temporary message with real id and server-provided display name
        final tempIndex = _messages.indexWhere(
          (m) => m.messageId.startsWith('temp_'),
        );
        if (tempIndex != -1) {
          final tempMessage = _messages[tempIndex];
          _messages[tempIndex] = tempMessage.copyWith(
            messageId: messageId,
            senderDisplayName: senderDisplayName ?? tempMessage.senderDisplayName,
            actualSenderId: actualSenderId ?? tempMessage.actualSenderId,
          );
          notifyListeners();
        }
      }
    };

    _wsClient!.onMessagesReceived = (data) {
      debugPrint('ChatProvider: Messages received via WebSocket');
      final messagesList = data['messages'] as List<dynamic>?;
      final hasMore = data['has_more'] as bool? ?? false;
      if (messagesList != null) {
        _handleMessagesReceived(
          messagesList.cast<Map<String, dynamic>>(),
          hasMore: hasMore,
        );
      }
    };

    _wsClient!.onError = (error) {
      debugPrint('ChatProvider: WebSocket error: $error');
      _errorMessage = error;
      _isConnected = false;
      notifyListeners();
    };

    _wsClient!.onDisconnected = () {
      debugPrint('ChatProvider: WebSocket disconnected');
      _isConnected = false;
      notifyListeners();
    };

    _wsClient!.onReconnecting = () {
      debugPrint('ChatProvider: WebSocket reconnecting...');
      _isConnected = false;
      notifyListeners();
    };

    // Connect to WebSocket server
    final connected = await _wsClient!.connect(
      userId: apiUserId,
      userType: userType,
      autoReconnect: true,
    );

    if (connected) {
      _isConnected = true;
      debugPrint('ChatProvider: WebSocket connection established');
    } else {
      _isConnected = false;
      debugPrint('ChatProvider: Failed to establish WebSocket connection');
    }
  }

  // Handle new message from WebSocket
  void _handleNewMessage(Map<String, dynamic> messageData) {
    try {
      final message = MessageModel.fromWebSocket(messageData);

      // Only add if it's for the current chat
      if (message.chatId != _chatConnectionId) return;

      final existingIndex = _messages.indexWhere((m) => m.messageId == message.messageId);
      if (existingIndex != -1) {
        final existing = _messages[existingIndex];
        _messages[existingIndex] = existing.copyWith(
          senderDisplayName: message.senderDisplayName ?? existing.senderDisplayName,
          actualSenderId: message.actualSenderId ?? existing.actualSenderId,
          messageType: message.messageType,
          imageUrl: message.imageUrl ?? existing.imageUrl,
        );
        notifyListeners();
        return;
      }

      _messages.add(message);
      _messages.sort((a, b) {
        final timeCompare = a.timestamp.compareTo(b.timestamp);
        if (timeCompare != 0) return timeCompare;
        return a.messageId.compareTo(b.messageId);
      });
      notifyListeners();
    } catch (e) {
      debugPrint('ChatProvider: Error handling new message: $e');
    }
  }

  // Handle messages received from server (initial load or load-more; server sends latest-first)
  void _handleMessagesReceived(
    List<Map<String, dynamic>> messagesData, {
    bool hasMore = false,
  }) {
    try {
      final newList = messagesData
          .map((data) => MessageModel.fromWebSocket(data))
          .toList();

      if (_isLoadingMore) {
        // Load more: prepend older messages (server returns older batch, no overlap)
        final existingIds = _messages.map((m) => m.messageId).toSet();
        for (var i = newList.length - 1; i >= 0; i--) {
          if (!existingIds.contains(newList[i].messageId)) {
            _messages.insert(0, newList[i]);
          }
        }
        _isLoadingMore = false;
      } else {
        _messages = newList;
      }

      _hasMore = hasMore;
      _isLoading = false;
      _errorMessage = null;

      // Sort chronologically: oldest first (top), newest last (bottom)
      _messages.sort((a, b) {
        final timeCompare = a.timestamp.compareTo(b.timestamp);
        if (timeCompare != 0) return timeCompare;
        return a.messageId.compareTo(b.messageId);
      });
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading messages: ${e.toString()}';
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
      debugPrint('ChatProvider: Error handling messages: $e');
    }
  }

  // Get or create chat connection via HTTP API
  // otherUserId should be the API user ID (staff_id or student_id) of the other user
  Future<String?> _getOrCreateChatConnection(
    String currentUserId,
    String otherUserId,
    AuthProvider? authProvider,
  ) async {
    try {
      final userType = _getUserTypeForWebSocket(authProvider);
      final apiUserId = await _getApiUserId(authProvider);

      if (apiUserId == null) {
        return null;
      }

      // Support user (uid 0) is always staff. Otherwise opposite of current user type.
      final otherUserType = otherUserId == supportUserId
          ? 'staff'
          : (userType == 'staff' ? 'student' : 'staff');

      // Admin opening a support thread: connection is Support <-> other user (student/teacher)
      final isAdminOpeningSupport = authProvider?.userType == UserType.admin && otherUserId != supportUserId;
      final userOneId = isAdminOpeningSupport ? supportUserId : apiUserId;
      final userOneType = isAdminOpeningSupport ? 'staff' : userType;

      // Get connection via HTTP API
      try {
        debugPrint(
          'ChatProvider: Requesting connection via HTTP API for users: $userOneId ($userOneType) <-> $otherUserId ($otherUserType)',
        );

        final result = await MessagesChatRepository.getConnection(
          userOneId: userOneId,
          userOneType: userOneType,
          userTwoId: otherUserId,
          userTwoType: otherUserType,
        );

        if (result['success'] == true) {
          final exists = result['exists'] as bool? ?? false;
          final connectionId = result['connection_id']?.toString();

          if (exists && connectionId != null) {
            debugPrint(
              'ChatProvider: Found existing connection: $connectionId',
            );
            return connectionId;
          } else {
            debugPrint('ChatProvider: Connection does not exist');
          }
        } else {
          final error = result['error'] ?? 'Unknown error';
          debugPrint(
            'ChatProvider: Failed to get connection via HTTP API: $error',
          );
          // Continue to try creating connection even if getting connection failed
        }
      } catch (e) {
        debugPrint('ChatProvider: Error getting connection via HTTP API: $e');
      }

      // If no connection found, try to create one via HTTP API
      debugPrint(
        'ChatProvider: No existing connection found, attempting to create one via HTTP API...',
      );
      try {
        debugPrint(
          'ChatProvider: Creating connection via HTTP API: $userOneId ($userOneType) <-> $otherUserId ($otherUserType)',
        );

        // Use HTTP API to create connection
        final result = await MessagesChatRepository.createConnection(
          userOneId: userOneId,
          userOneType: userOneType,
          userTwoId: otherUserId,
          userTwoType: otherUserType,
        );

        if (result['success'] == true && result['connection_id'] != null) {
          final connectionId = result['connection_id'].toString();
          debugPrint(
            'ChatProvider: Successfully created connection via HTTP API: $connectionId',
          );
          return connectionId;
        } else {
          final error = result['error'] ?? 'Unknown error';
          debugPrint(
            'ChatProvider: Failed to create connection via HTTP API: $error',
          );
        }
      } catch (e) {
        debugPrint('ChatProvider: Error creating connection via HTTP API: $e');
      }

      debugPrint(
        'ChatProvider: No connection found and could not create one for users: $apiUserId <-> $otherUserId',
      );
      debugPrint(
        'ChatProvider: NOTE: Both users must exist in fl_chat_users table before a connection can be created.',
      );
      debugPrint(
        'ChatProvider: Please ensure user $apiUserId (type: $userType) and user $otherUserId exist in the database.',
      );
      return null;
    } catch (e) {
      debugPrint('ChatProvider: Error getting or creating chat connection: $e');
      return null;
    }
  }

  // Initialize chat with another user
  Future<void> initializeChat(
    String otherUserId, {
    AuthProvider? authProvider,
  }) async {
    final currentUserId = getCurrentUserId(authProvider);
    if (currentUserId == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return;
    }

    // Initialize WebSocket if not already connected
    await _initializeWebSocket(authProvider);

    // Find or create chat connection
    _chatConnectionId = await _getOrCreateChatConnection(
      currentUserId,
      otherUserId,
      authProvider,
    );

    if (_chatConnectionId == null) {
      _errorMessage = 'Failed to create chat connection';
      notifyListeners();
      return;
    }

    // Load messages
    await _loadMessages();
  }

  // Set chat connection ID and load messages (for existing chats)
  // chatId can be either:
  // 1. A Firestore document ID (long alphanumeric string) - needs conversion
  // 2. A database connection ID (numeric string) - can be used directly
  Future<void> setChatId(String chatId, {AuthProvider? authProvider}) async {
    // Check if it's a Firestore document ID (long alphanumeric) or database ID (numeric)
    final isNumeric = RegExp(r'^\d+$').hasMatch(chatId);

    if (isNumeric) {
      // It's already a database connection ID
      _chatConnectionId = chatId;
      // Initialize WebSocket if not connected
      await _initializeWebSocket(authProvider);
      _loadMessages();
    } else {
      // It's a Firestore document ID, need to convert to database connection ID
      await _convertFirestoreChatIdToConnectionId(chatId, authProvider);
    }
  }

  // Convert Firestore chat ID to database connection ID
  Future<void> _convertFirestoreChatIdToConnectionId(
    String firestoreChatId,
    AuthProvider? authProvider,
  ) async {
    try {
      // First, get the chat data from Firestore to get user IDs
      // We'll need to import firestore for this
      final firestore = FirebaseFirestore.instance;
      final chatDoc = await firestore
          .collection('chats')
          .doc(firestoreChatId)
          .get();

      if (!chatDoc.exists) {
        _errorMessage = 'Chat not found';
        notifyListeners();
        return;
      }

      final chatData = chatDoc.data();
      final user1Id = chatData?['user1Id'] as String?;
      final user2Id = chatData?['user2Id'] as String?;

      if (user1Id == null || user2Id == null) {
        _errorMessage = 'Invalid chat data';
        notifyListeners();
        return;
      }

      // Get current user's API ID
      final currentApiUserId = await _getApiUserId(authProvider);
      if (currentApiUserId == null) {
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return;
      }

      // The user1Id and user2Id from Firestore are already API IDs (document IDs)
      // Determine which one is the current user and which is the other user
      String? otherApiUserId;
      if (user1Id == currentApiUserId) {
        otherApiUserId = user2Id;
      } else if (user2Id == currentApiUserId) {
        otherApiUserId = user1Id;
      } else {
        // Current user ID doesn't match either - this shouldn't happen
        debugPrint(
          'ChatProvider: Current user ID ($currentApiUserId) does not match chat users ($user1Id, $user2Id)',
        );
        _errorMessage = 'Could not determine other user';
        notifyListeners();
        return;
      }

      debugPrint(
        'ChatProvider: Converting Firestore chat. Current: $currentApiUserId, Other: $otherApiUserId',
      );

      // Now find or create the database connection
      _chatConnectionId = await _getOrCreateChatConnection(
        currentApiUserId,
        otherApiUserId,
        authProvider,
      );

      if (_chatConnectionId == null) {
        _errorMessage =
            'Failed to find or create chat connection. Please ensure both users exist in the chat system.';
        debugPrint(
          'ChatProvider: Failed to get/create connection for users: $currentApiUserId <-> $otherApiUserId',
        );
        notifyListeners();
        return;
      }

      debugPrint(
        'ChatProvider: Found/created connection ID: $_chatConnectionId',
      );

      // Initialize WebSocket if not connected
      await _initializeWebSocket(authProvider);
      await _loadMessages();
    } catch (e) {
      debugPrint('ChatProvider: Error converting Firestore chat ID: $e');
      _errorMessage = 'Error loading chat: ${e.toString()}';
      notifyListeners();
    }
  }

  // Load last 30 messages for the current chat (initial load)
  Future<void> _loadMessages() async {
    if (_chatConnectionId == null) return;

    _isLoading = true;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();

    if (_wsClient != null && _wsClient!.isConnected) {
      _wsClient!.getMessages(_chatConnectionId!, limit: 30);
    } else {
      debugPrint(
        'ChatProvider: Cannot load messages - WebSocket not connected',
      );
      _isLoading = false;
      _errorMessage = 'WebSocket not connected';
      notifyListeners();
    }
  }

  /// Load older messages (for "load more" / WhatsApp-style scroll up)
  void loadMoreOlderMessages() {
    if (_chatConnectionId == null || _isLoadingMore || !_hasMore || _messages.isEmpty) return;

    final oldestId = int.tryParse(_messages.first.messageId);
    if (oldestId == null) return;

    _isLoadingMore = true;
    notifyListeners();

    _wsClient?.getMessages(_chatConnectionId!, limit: 30, beforeId: oldestId);
  }

  // Send a text or image message
  Future<bool> sendMessage(
    String text, {
    AuthProvider? authProvider,
    String messageType = 'text',
    String? imageUrl,
  }) async {
    if (_chatConnectionId == null) return false;
    if (messageType == 'text' && text.trim().isEmpty) return false;
    if (messageType == 'image' && (imageUrl == null || imageUrl.isEmpty)) return false;
    if (messageType == 'document' && (imageUrl == null || imageUrl.isEmpty)) return false;

    final apiUserId = await _getApiUserId(authProvider);
    if (apiUserId == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    final displayText = messageType == 'image'
        ? (text.trim().isEmpty ? 'Photo' : text.trim())
        : (messageType == 'document' ? (text.trim().isEmpty ? 'Document' : text.trim()) : text.trim());

    final optimisticMessage = MessageModel(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: _chatConnectionId!,
      senderId: apiUserId,
      text: displayText,
      timestamp: DateTime.now(),
      isRead: false,
      messageType: messageType,
      imageUrl: imageUrl,
      uploadProgress: null,
    );

    _messages.add(optimisticMessage);
    _messages.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) return timeCompare;
      return a.messageId.compareTo(b.messageId);
    });
    notifyListeners();

    try {
      final userType = _getUserTypeForWebSocket(authProvider);

      if (_wsClient != null && _wsClient!.isConnected) {
        _wsClient!.sendMessage(
          chatConnectionId: _chatConnectionId!,
          message: displayText,
          senderId: apiUserId,
          userType: userType,
          messageType: messageType,
          imageUrl: imageUrl,
        );
      } else {
        // Remove optimistic message on error
        _messages.removeWhere(
          (m) => m.messageId == optimisticMessage.messageId,
        );
        notifyListeners();
        _errorMessage = 'WebSocket not connected';
        notifyListeners();
        debugPrint(
          'ChatProvider: Cannot send message - WebSocket not connected',
        );
        return false;
      }

      // Message will be confirmed via onMessageSent callback
      // The server will also send it back via onNewMessage
      // We'll update the temporary message ID when we receive the real one

      return true;
    } catch (e) {
      // Remove optimistic message on error
      _messages.removeWhere((m) => m.messageId == optimisticMessage.messageId);
      notifyListeners();
      _errorMessage = 'Error sending message: ${e.toString()}';
      notifyListeners();
      debugPrint('ChatProvider: Error sending message: $e');
      return false;
    }
  }

  // Create chat user entry in database
  /// This should be called after user login to ensure they exist in fl_chat_users table
  Future<bool> createChatUser({AuthProvider? authProvider}) async {
    final apiUserId = await _getApiUserId(authProvider);
    if (apiUserId == null) {
      debugPrint('ChatProvider: Cannot create chat user - no API user ID');
      return false;
    }

    final userType = _getUserTypeForWebSocket(authProvider);

    debugPrint(
      'ChatProvider: Creating chat user via HTTP API - userId: $apiUserId, type: $userType',
    );

    try {
      // Use HTTP API instead of WebSocket
      final result = await MessagesChatRepository.createChatUser(
        userId: apiUserId,
        userType: userType,
      );

      if (result['success'] == true) {
        final chatUserId = result['chat_user_id'];
        final isNew = result['is_new'] ?? false;
        debugPrint(
          'ChatProvider: Chat user ${isNew ? "created" : "verified"} successfully with ID: $chatUserId',
        );
        return true;
      } else {
        final error = result['error'] ?? 'Unknown error';
        debugPrint('ChatProvider: Failed to create chat user: $error');
        return false;
      }
    } catch (e) {
      debugPrint('ChatProvider: Error in createChatUser: $e');
      return false;
    }
  }

  // Mark messages as read (notify server and update local state)
  Future<void> markMessagesAsRead({AuthProvider? authProvider}) async {
    if (_chatConnectionId == null) return;

    try {
      final apiUserId = await _getApiUserId(authProvider);
      if (apiUserId == null) return;

      _wsClient?.markMessagesRead(_chatConnectionId!);

      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        if (message.senderId != apiUserId && message.actualSenderId != apiUserId && !message.isRead) {
          _messages[i] = message.copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ChatProvider: Error marking messages as read: $e');
    }
  }

  /// Report the other user in this chat (saved to complain_reports table)
  void reportUser({
    required String reportedUserId,
    required String reportedUserType,
    required String reason,
  }) {
    if (_chatConnectionId == null) return;
    _wsClient?.reportUser(
      reportedUserId: reportedUserId,
      reportedUserType: reportedUserType,
      reason: reason,
      chatConnectionId: _chatConnectionId,
    );
  }

  /// Add an optimistic document message (upload in progress). Returns temp message id.
  String? addOptimisticDocumentMessage(String filename) {
    if (_chatConnectionId == null) return null;
    final apiUserId = _currentUserApiId;
    if (apiUserId == null) return null;
    final tempId = 'temp_doc_${DateTime.now().millisecondsSinceEpoch}';
    final msg = MessageModel(
      messageId: tempId,
      chatId: _chatConnectionId!,
      senderId: apiUserId,
      text: filename,
      timestamp: DateTime.now(),
      isRead: false,
      messageType: 'document',
      imageUrl: null,
      uploadProgress: 0.0,
    );
    _messages.add(msg);
    _messages.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) return timeCompare;
      return a.messageId.compareTo(b.messageId);
    });
    notifyListeners();
    return tempId;
  }

  /// Update upload progress for an optimistic document message.
  void updateDocumentUploadProgress(String tempId, double progress) {
    final index = _messages.indexWhere((m) => m.messageId == tempId);
    if (index == -1) return;
    _messages[index] = _messages[index].copyWith(uploadProgress: progress.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Finalize document message (set URL, clear progress) and send via WebSocket.
  Future<bool> finalizeAndSendDocumentMessage(
    String tempId,
    String documentUrl,
    String filename, {
    AuthProvider? authProvider,
  }) async {
    if (_chatConnectionId == null) return false;
    final index = _messages.indexWhere((m) => m.messageId == tempId);
    if (index == -1) return false;
    final apiUserId = await _getApiUserId(authProvider);
    if (apiUserId == null) return false;
    _messages[index] = _messages[index].copyWith(
      imageUrl: documentUrl,
      clearUploadProgress: true,
    );
    notifyListeners();
    final userType = _getUserTypeForWebSocket(authProvider);
    _wsClient?.sendMessage(
      chatConnectionId: _chatConnectionId!,
      message: filename,
      senderId: apiUserId,
      userType: userType,
      messageType: 'document',
      imageUrl: documentUrl,
    );
    return true;
  }

  /// Remove optimistic document message (e.g. on upload failure).
  void removeOptimisticDocumentMessage(String tempId) {
    _messages.removeWhere((m) => m.messageId == tempId);
    notifyListeners();
  }
}
