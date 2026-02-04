import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/models/message_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/web_socket_client.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';

class ChatProvider with ChangeNotifier {
  WebSocketClient? _wsClient;
  String? _currentUserId;
  String? _currentUserType; // 'staff' or 'student'
  String? _currentUserApiId; // The actual staff_id or student_id from API

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _chatConnectionId;
  bool _isConnected = false;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
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
      if (messageId != null) {
        // Update temporary message ID with real one
        final tempIndex = _messages.indexWhere(
          (m) => m.messageId.startsWith('temp_'),
        );
        if (tempIndex != -1) {
          final tempMessage = _messages[tempIndex];
          _messages[tempIndex] = tempMessage.copyWith(messageId: messageId);
          notifyListeners();
        }
      }
    };

    _wsClient!.onMessagesReceived = (data) {
      debugPrint('ChatProvider: Messages received via WebSocket');
      final messagesList = data['messages'] as List<dynamic>?;
      if (messagesList != null) {
        _handleMessagesReceived(messagesList.cast<Map<String, dynamic>>());
      }
    };

    _wsClient!.onChatUserCreated = (data) {
      debugPrint('ChatProvider: Chat user created');
      final chatUserId = data['chat_user_id']?.toString();
      final isNew = data['is_new'] as bool? ?? false;
      debugPrint('ChatProvider: Chat user ID: $chatUserId, is_new: $isNew');
    };

    _wsClient!.onConnectionsReceived = (data) {
      debugPrint('ChatProvider: Connections received via WebSocket');
      // This will be handled by the completer in _getOrCreateChatConnection
    };

    _wsClient!.onConnectionCreated = (data) {
      debugPrint('ChatProvider: Connection created via WebSocket');
      // This will be handled by the completer in _getOrCreateChatConnection
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
      if (message.chatId == _chatConnectionId) {
        // Check if message already exists (avoid duplicates)
        final exists = _messages.any((m) => m.messageId == message.messageId);
        if (!exists) {
          _messages.add(message);
          // Sort by timestamp (ascending - oldest first), then by message ID as secondary key
          _messages.sort((a, b) {
            final timeCompare = a.timestamp.compareTo(b.timestamp);
            if (timeCompare != 0) return timeCompare;
            // If timestamps are equal, sort by message ID (ascending)
            return a.messageId.compareTo(b.messageId);
          });
          notifyListeners();

          // Scroll to bottom would be handled by UI
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: Error handling new message: $e');
    }
  }

  // Handle messages received from server
  void _handleMessagesReceived(List<Map<String, dynamic>> messagesData) {
    try {
      _messages = messagesData
          .map((data) => MessageModel.fromWebSocket(data))
          .toList();

      // Sort by timestamp (ascending - oldest first), then by message ID as secondary key
      _messages.sort((a, b) {
        final timeCompare = a.timestamp.compareTo(b.timestamp);
        if (timeCompare != 0) return timeCompare;
        // If timestamps are equal, sort by message ID (ascending)
        return a.messageId.compareTo(b.messageId);
      });
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading messages: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('ChatProvider: Error handling messages: $e');
    }
  }

  // Get or create chat connection via WebSocket
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

      // Ensure WebSocket is connected
      if (_wsClient == null || !_wsClient!.isConnected) {
        await _initializeWebSocket(authProvider);
      }

      if (_wsClient == null || !_wsClient!.isConnected) {
        debugPrint(
          'ChatProvider: Cannot get connections - WebSocket not connected',
        );
        return null;
      }

      // Create completers for async operations
      final connectionsCompleter = Completer<List<Map<String, dynamic>>>();
      final createConnectionCompleter = Completer<String?>();

      // Store original callbacks
      final originalConnectionsCallback = _wsClient!.onConnectionsReceived;
      final originalConnectionCreatedCallback = _wsClient!.onConnectionCreated;
      final originalErrorCallback = _wsClient!.onError;

      // Set up one-time callback for connections
      _wsClient!.onConnectionsReceived = (data) {
        if (data['status'] == 'success' && data['connections'] != null) {
          final connections = (data['connections'] as List)
              .cast<Map<String, dynamic>>();
          connectionsCompleter.complete(connections);
        } else {
          connectionsCompleter.complete([]);
        }
        _wsClient!.onConnectionsReceived = originalConnectionsCallback;
      };

      // Set up one-time callback for connection creation
      _wsClient!.onConnectionCreated = (data) {
        if (data['status'] == 'success' && data['connection_id'] != null) {
          final connectionId = data['connection_id'].toString();
          createConnectionCompleter.complete(connectionId);
        } else {
          createConnectionCompleter.complete(null);
        }
        _wsClient!.onConnectionCreated = originalConnectionCreatedCallback;
      };

      // Set up error callback
      _wsClient!.onError = (error) {
        if (error.contains('connection') ||
            error.contains('get_connections') ||
            error.contains('create_connection')) {
          debugPrint('ChatProvider: Error with connections: $error');
          if (!connectionsCompleter.isCompleted) {
            connectionsCompleter.complete([]);
          }
          if (!createConnectionCompleter.isCompleted) {
            createConnectionCompleter.complete(null);
          }
          _wsClient!.onError = originalErrorCallback;
        } else {
          originalErrorCallback?.call(error);
        }
      };

      // Request connections via WebSocket
      try {
        debugPrint(
          'ChatProvider: Requesting connections for user: $apiUserId (type: $userType)',
        );
        _wsClient!.getConnections(userId: apiUserId, userType: userType);

        // Wait for connections with timeout
        final connections = await connectionsCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('ChatProvider: Timeout waiting for connections');
            return <Map<String, dynamic>>[];
          },
        );

        debugPrint('ChatProvider: Found ${connections.length} connections');

        // Find connection with the other user
        for (var conn in connections) {
          final connectionId = conn['id']?.toString();
          final userOneId = conn['user_one_id']?.toString();
          final userTwoId = conn['user_two_id']?.toString();
          final otherUserIdFromConn = conn['other_user_id']?.toString();

          debugPrint(
            'ChatProvider: Checking connection $connectionId: user1=$userOneId, user2=$userTwoId, other=$otherUserIdFromConn, looking for=$otherUserId',
          );

          // Check if otherUserId matches either user in the connection
          if (connectionId != null &&
              (userOneId == otherUserId ||
                  userTwoId == otherUserId ||
                  otherUserIdFromConn == otherUserId)) {
            debugPrint(
              'ChatProvider: Found matching connection: $connectionId',
            );
            // Restore callbacks
            _wsClient!.onConnectionsReceived = originalConnectionsCallback;
            _wsClient!.onConnectionCreated = originalConnectionCreatedCallback;
            _wsClient!.onError = originalErrorCallback;
            return connectionId;
          }
        }
      } catch (e) {
        debugPrint('ChatProvider: Error getting connections: $e');
      }

      // If no connection found, try to create one via WebSocket
      debugPrint(
        'ChatProvider: No existing connection found, attempting to create one...',
      );
      try {
        // Determine other user type (opposite of current user type)
        final otherUserType = userType == 'staff' ? 'student' : 'staff';

        debugPrint(
          'ChatProvider: Creating connection: $apiUserId ($userType) <-> $otherUserId ($otherUserType)',
        );

        _wsClient!.createConnection(
          userOneId: apiUserId,
          userOneType: userType,
          userTwoId: otherUserId,
          userTwoType: otherUserType,
        );

        // Wait for connection creation with timeout
        final connectionId = await createConnectionCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('ChatProvider: Timeout waiting for connection creation');
            return null;
          },
        );

        if (connectionId != null) {
          debugPrint(
            'ChatProvider: Successfully created connection: $connectionId',
          );
          // Restore callbacks
          _wsClient!.onConnectionsReceived = originalConnectionsCallback;
          _wsClient!.onConnectionCreated = originalConnectionCreatedCallback;
          _wsClient!.onError = originalErrorCallback;
          return connectionId;
        } else {
          debugPrint('ChatProvider: Failed to create connection');
        }
      } catch (e) {
        debugPrint('ChatProvider: Error creating connection: $e');
      }

      // Restore callbacks
      _wsClient!.onConnectionsReceived = originalConnectionsCallback;
      _wsClient!.onConnectionCreated = originalConnectionCreatedCallback;
      _wsClient!.onError = originalErrorCallback;

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

  // Load messages for the current chat
  Future<void> _loadMessages() async {
    if (_chatConnectionId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Request messages via WebSocket
    if (_wsClient != null && _wsClient!.isConnected) {
      _wsClient!.getMessages(_chatConnectionId!);
    } else {
      debugPrint(
        'ChatProvider: Cannot load messages - WebSocket not connected',
      );
      _isLoading = false;
      _errorMessage = 'WebSocket not connected';
      notifyListeners();
    }
  }

  // Send a message
  Future<bool> sendMessage(String text, {AuthProvider? authProvider}) async {
    if (_chatConnectionId == null || text.trim().isEmpty) {
      return false;
    }

    final apiUserId = await _getApiUserId(authProvider);
    if (apiUserId == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    // Create optimistic message
    final optimisticMessage = MessageModel(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: _chatConnectionId!,
      senderId: apiUserId,
      text: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Add optimistically
    _messages.add(optimisticMessage);
    // Sort by timestamp (ascending - oldest first), then by message ID as secondary key
    _messages.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) return timeCompare;
      // If timestamps are equal, sort by message ID (ascending)
      return a.messageId.compareTo(b.messageId);
    });
    notifyListeners();

    try {
      final userType = _getUserTypeForWebSocket(authProvider);

      // Send message via WebSocket
      if (_wsClient != null && _wsClient!.isConnected) {
        _wsClient!.sendMessage(
          chatConnectionId: _chatConnectionId!,
          message: text.trim(),
          senderId: apiUserId,
          userType: userType,
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

  // Mark messages as read
  Future<void> markMessagesAsRead({AuthProvider? authProvider}) async {
    if (_chatConnectionId == null) return;

    // This would require an API endpoint to mark messages as read
    // For now, we'll just update local state
    try {
      final apiUserId = await _getApiUserId(authProvider);
      if (apiUserId == null) return;

      // Update local messages
      for (var message in _messages) {
        if (message.senderId != apiUserId && !message.isRead) {
          // Mark as read locally
          // In a real implementation, you'd call an API endpoint
          final index = _messages.indexOf(message);
          _messages[index] = message.copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ChatProvider: Error marking messages as read: $e');
    }
  }
}
