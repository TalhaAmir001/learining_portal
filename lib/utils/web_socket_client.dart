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
  /// Called when server broadcasts a new notice (notice board); payload has 'notice' map.
  Function(Map<String, dynamic>)? onNewNotice;
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

        case 'new_notice':
          _handleNewNotice(data);
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

  /// Handle new notice broadcast (notice board)
  void _handleNewNotice(Map<String, dynamic> data) {
    debugPrint('WebSocketClient: New notice received');
    onNewNotice?.call(data);
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

  /// Send a chat message (text or image)
  void sendMessage({
    required String chatConnectionId,
    required String message,
    required String senderId,
    String? userType,
    String messageType = 'text',
    String? imageUrl,
  }) {
    final payload = <String, dynamic>{
      'action': 'send_message',
      'chat_connection_id': chatConnectionId,
      'message': message,
      'sender_id': senderId,
      'user_type': userType ?? _userType,
    };
    if (messageType == 'image' || messageType == 'document') {
      payload['message_type'] = messageType;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        payload['image_url'] = imageUrl;
        if (messageType == 'document') {
          payload['document_url'] = imageUrl;
        }
      }
    }
    _sendMessage(payload);
  }

  /// Request messages for a chat connection (paginated)
  /// [limit] - Max messages to return (default 30)
  /// [beforeId] - Load messages older than this id (for "load more")
  void getMessages(
    String chatConnectionId, {
    int limit = 30,
    int? beforeId,
  }) {
    final payload = <String, dynamic>{
      'action': 'get_messages',
      'chat_connection_id': chatConnectionId,
      'limit': limit,
    };
    if (beforeId != null && beforeId > 0) {
      payload['before_id'] = beforeId;
    }
    _sendMessage(payload);
  }

  /// Mark messages in this chat as read
  void markMessagesRead(String chatConnectionId) {
    _sendMessage({
      'action': 'mark_messages_read',
      'chat_connection_id': chatConnectionId,
    });
  }

  /// Report a user (saved to complain_reports table)
  void reportUser({
    required String reportedUserId,
    required String reportedUserType,
    required String reason,
    String? chatConnectionId,
  }) {
    _sendMessage({
      'action': 'report_user',
      'reported_user_id': reportedUserId,
      'reported_user_type': reportedUserType,
      'reason': reason,
      if (chatConnectionId != null && chatConnectionId.isNotEmpty) 'chat_connection_id': chatConnectionId,
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
