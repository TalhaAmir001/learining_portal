import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket client for real-time chat communication
///
/// This client handles all WebSocket operations defined in the server:
/// - connect: Establish connection with user_id and user_type
/// - send_message: Send a message to a chat connection
/// - get_messages: Retrieve messages for a chat connection
/// - create_chat_user: Create a chat user entry in the database
class WebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isConnectionConfirmed = false; // True when server confirms connection
  String? _userId;
  String? _userType;
  Completer<bool>?
  _connectionCompleter; // For waiting on connection confirmation

  // Reconnection settings
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;

  // WebSocket URL - adjust based on your server configuration
  // For production, use wss:// (secure WebSocket)
  // For development, use ws:// (non-secure WebSocket)
  static const String _wsHost = 'portal.gcsewithrosi.co.uk';
  static const int _wsPort = 8080;
  static const bool _useSecure = false; // Set to true for wss://

  String get _wsUrl {
    final protocol = _useSecure ? 'wss' : 'ws';
    return '$protocol://$_wsHost:$_wsPort';
  }

  // Callbacks
  Function(Map<String, dynamic>)? onConnected;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onMessageSent;
  Function(Map<String, dynamic>)? onMessagesReceived;
  Function(Map<String, dynamic>)? onChatUserCreated;
  Function(Map<String, dynamic>)? onConnectionsReceived;
  Function(Map<String, dynamic>)? onConnectionCreated;
  Function(String)? onError;
  Function()? onDisconnected;
  Function()? onReconnecting;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get userId => _userId;
  String? get userType => _userType;

  /// Connect to WebSocket server with user credentials
  ///
  /// [userId] - The user ID (staff_id or student_id)
  /// [userType] - The user type ('staff' or 'student')
  /// [autoReconnect] - Whether to automatically reconnect on disconnect (default: true)
  Future<bool> connect({
    required String userId,
    required String userType,
    bool autoReconnect = true,
  }) async {
    if (_isConnecting || (_isConnected && _userId == userId)) {
      debugPrint('WebSocketClient: Already connected or connecting');
      return _isConnected;
    }

    _userId = userId;
    _userType = userType;
    _shouldReconnect = autoReconnect;

    return await _connect();
  }

  /// Internal connection method
  Future<bool> _connect() async {
    if (_isConnecting) {
      return false;
    }

    _isConnecting = true;
    _reconnectAttempts = 0;

    try {
      debugPrint('WebSocketClient: Connecting to $_wsUrl');

      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Listen to incoming messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocketClient: Stream error: $error');
          _handleError(error);
        },
        onDone: () {
          debugPrint('WebSocketClient: Stream done');
          _handleDone();
        },
        cancelOnError: false,
      );

      debugPrint('WebSocketClient: Stream listener attached');

      // Wait a bit for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // Create completer to wait for connection confirmation
      _connectionCompleter = Completer<bool>();
      _isConnectionConfirmed = false;

      // Mark as connected (channel is established, waiting for server confirmation)
      _isConnected = true;
      _isConnecting = false;

      // Send connect action directly (bypass _sendMessage checks since we're establishing connection)
      final connectMessage = {
        'action': 'connect',
        'user_id': _userId,
        'user_type': _userType,
      };

      try {
        final jsonMessage = json.encode(connectMessage);
        debugPrint('WebSocketClient: Sending connect message: $jsonMessage');
        _channel!.sink.add(jsonMessage);
        debugPrint('WebSocketClient: Connect message sent successfully');
      } catch (e) {
        debugPrint('WebSocketClient: Error sending connect message: $e');
        _isConnected = false;
        if (_connectionCompleter != null &&
            !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(false);
        }
        throw e;
      }

      debugPrint('WebSocketClient: Waiting for connection confirmation...');

      // Wait for connection confirmation from server (with timeout)
      try {
        final confirmed = await _connectionCompleter!.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('WebSocketClient: Connection confirmation timeout');
            return false;
          },
        );

        if (confirmed) {
          debugPrint('WebSocketClient: Connection confirmed by server');
          return true;
        } else {
          debugPrint('WebSocketClient: Connection not confirmed by server');
          _isConnected = false;
          return false;
        }
      } catch (e) {
        debugPrint(
          'WebSocketClient: Error waiting for connection confirmation: $e',
        );
        _isConnected = false;
        return false;
      }
    } catch (e) {
      debugPrint('WebSocketClient: Connection error: $e');
      _isConnecting = false;
      _isConnected = false;
      _isConnectionConfirmed = false;

      // Complete connection completer if still waiting
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
      }
      _connectionCompleter = null;

      if (_shouldReconnect) {
        _scheduleReconnect();
      }

      onError?.call('Connection failed: ${e.toString()}');
      return false;
    }
  }

  /// Handle incoming messages from server
  void _handleMessage(dynamic message) {
    try {
      debugPrint(
        'WebSocketClient: Raw message received: ${message.toString()}',
      );
      final data = json.decode(message.toString()) as Map<String, dynamic>;
      final action = data['action'] as String?;

      debugPrint(
        'WebSocketClient: Received message - action: $action, full data: $data',
      );

      switch (action) {
        case 'connected':
          _handleConnected(data);
          break;

        case 'new_message':
          _handleNewMessage(data);
          break;

        case 'message_sent':
          _handleMessageSent(data);
          break;

        case 'messages':
          _handleMessages(data);
          break;

        case 'chat_user_created':
          _handleChatUserCreated(data);
          break;

        case 'connections':
          _handleConnections(data);
          break;

        case 'connection_created':
          _handleConnectionCreated(data);
          break;

        case 'error':
          _handleServerError(data);
          break;

        default:
          debugPrint('WebSocketClient: Unknown action: $action');
          debugPrint('WebSocketClient: Full message: $data');
          // Even if action is unknown, log it so we can see what the server sent
          debugPrint(
            'WebSocketClient: Received message with unknown action, but message was received',
          );
      }
    } catch (e) {
      debugPrint('WebSocketClient: Error parsing message: $e');
      debugPrint('WebSocketClient: Raw message: $message');
      onError?.call('Failed to parse message: ${e.toString()}');
    }
  }

  /// Handle connection confirmation
  void _handleConnected(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Connection confirmed by server');
    _isConnectionConfirmed = true;

    // Complete the connection completer if it exists
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(true);
    }

    onConnected?.call(data);
  }

  /// Handle new message received
  void _handleNewMessage(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: New message received');
    onNewMessage?.call(data);
  }

  /// Handle message sent confirmation
  void _handleMessageSent(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Message sent confirmation');
    onMessageSent?.call(data);
  }

  /// Handle messages list received
  void _handleMessages(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Messages received');
    onMessagesReceived?.call(data);
  }

  /// Handle chat user created confirmation
  void _handleChatUserCreated(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Chat user created - full data: $data');
    final status = data['status'] as String?;
    final chatUserId = data['chat_user_id'];
    final isNew = data['is_new'] as bool?;
    debugPrint(
      'WebSocketClient: Chat user created - status: $status, chat_user_id: $chatUserId, is_new: $isNew',
    );
    onChatUserCreated?.call(data);
  }

  /// Handle connections received
  void _handleConnections(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Connections received');
    onConnectionsReceived?.call(data);
  }

  /// Handle connection created confirmation
  void _handleConnectionCreated(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: Connection created - full data: $data');
    onConnectionCreated?.call(data);
  }

  /// Handle server error
  void _handleServerError(Map<String, dynamic> data) {
    final errorMessage = data['message'] as String? ?? 'Unknown error';
    debugPrint('WebSocketClient: Server error received - full data: $data');
    debugPrint('WebSocketClient: Server error message: $errorMessage');
    onError?.call(errorMessage);
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    debugPrint('WebSocketClient: WebSocket error: $error');
    _isConnected = false;
    _isConnectionConfirmed = false;

    // Complete connection completer if still waiting
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }

    onError?.call('WebSocket error: ${error.toString()}');

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket connection closed
  void _handleDone() {
    debugPrint('WebSocketClient: Connection closed');
    _isConnected = false;
    _isConnectionConfirmed = false;

    // Complete connection completer if still waiting
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }

    onDisconnected?.call();

    if (_shouldReconnect && _userId != null) {
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocketClient: Max reconnection attempts reached');
      onError?.call(
        'Failed to reconnect after $_maxReconnectAttempts attempts',
      );
      return;
    }

    _reconnectAttempts++;
    final delay = _reconnectDelay * _reconnectAttempts;

    debugPrint(
      'WebSocketClient: Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s',
    );

    onReconnecting?.call();

    _reconnectTimer = Timer(delay, () {
      debugPrint('WebSocketClient: Attempting to reconnect...');
      _connect();
    });
  }

  /// Send a message to the server
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null || !_isConnected) {
      debugPrint('WebSocketClient: Cannot send message - not connected');
      onError?.call('Not connected to WebSocket server');
      return;
    }

    // For non-connect messages, wait for connection confirmation
    if (message['action'] != 'connect' && !_isConnectionConfirmed) {
      debugPrint(
        'WebSocketClient: Cannot send message - connection not confirmed yet',
      );
      onError?.call('Connection not confirmed by server');
      return;
    }

    try {
      final jsonMessage = json.encode(message);
      debugPrint('WebSocketClient: Sending message: $jsonMessage');
      _channel!.sink.add(jsonMessage);
      debugPrint(
        'WebSocketClient: Message sent successfully: ${message['action']}',
      );
    } catch (e) {
      debugPrint('WebSocketClient: Error sending message: $e');
      onError?.call('Failed to send message: ${e.toString()}');
    }
  }

  /// Send a chat message
  ///
  /// [chatConnectionId] - The chat connection ID
  /// [message] - The message text
  /// [senderId] - The sender's user ID (staff_id or student_id)
  /// [userType] - Optional user type (uses connected user type if not provided)
  void sendMessage({
    required String chatConnectionId,
    required String message,
    required String senderId,
    String? userType,
  }) {
    _sendMessage({
      'action': 'send_message',
      'chat_connection_id': chatConnectionId,
      'message': message,
      'sender_id': senderId,
      'user_type': userType ?? _userType,
    });
  }

  /// Request messages for a chat connection
  ///
  /// [chatConnectionId] - The chat connection ID
  void getMessages(String chatConnectionId) {
    _sendMessage({
      'action': 'get_messages',
      'chat_connection_id': chatConnectionId,
    });
  }

  /// Create a chat user entry in the database
  ///
  /// [userId] - The user ID (staff_id or student_id)
  /// [userType] - The user type ('staff' or 'student')
  void createChatUser({required String userId, required String userType}) {
    final message = {
      'action': 'create_chat_user',
      'user_id': userId,
      'user_type': userType,
    };
    debugPrint(
      'WebSocketClient: createChatUser called with userId: $userId, userType: $userType',
    );
    debugPrint('WebSocketClient: createChatUser message: $message');
    _sendMessage(message);
  }

  /// Get all chat connections for the current user
  ///
  /// [userId] - Optional user ID (uses connected user ID if not provided)
  /// [userType] - Optional user type (uses connected user type if not provided)
  void getConnections({String? userId, String? userType}) {
    _sendMessage({
      'action': 'get_connections',
      'user_id': userId ?? _userId,
      'user_type': userType ?? _userType,
    });
  }

  /// Create a chat connection between two users
  ///
  /// [userOneId] - The first user's ID (staff_id or student_id)
  /// [userOneType] - The first user's type ('staff' or 'student')
  /// [userTwoId] - The second user's ID (staff_id or student_id)
  /// [userTwoType] - The second user's type ('staff' or 'student')
  void createConnection({
    required String userOneId,
    required String userOneType,
    required String userTwoId,
    required String userTwoType,
  }) {
    _sendMessage({
      'action': 'create_connection',
      'user_one_id': userOneId,
      'user_one_type': userOneType,
      'user_two_id': userTwoId,
      'user_two_type': userTwoType,
    });
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    _subscription?.cancel();
    _subscription = null;

    if (_channel != null) {
      _channel!.sink.close(status.normalClosure);
      _channel = null;
    }

    _isConnected = false;
    _isConnecting = false;
    _isConnectionConfirmed = false;

    // Complete connection completer if still waiting
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }
    _connectionCompleter = null;

    _userId = null;
    _userType = null;

    debugPrint('WebSocketClient: Disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
  }
}
