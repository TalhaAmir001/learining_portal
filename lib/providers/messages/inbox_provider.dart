import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../network/domain/messages_chat_repository.dart';

class InboxProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = firestore;
  AuthProvider? _authProvider;

  List<ChatModel> _chats = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Set auth provider (called from widget that has access to context)
  void setAuthProvider(AuthProvider authProvider) {
    debugPrint(
      'setAuthProvider called. Authenticated: ${authProvider.isAuthenticated}, UserId: ${authProvider.currentUserId}',
    );
    _authProvider = authProvider;
    // Reload chats when auth provider is set
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      debugPrint('Loading chats...');
      _loadChats();
    } else {
      debugPrint('Not authenticated, skipping chat load');
      _isLoading = false;
      _errorMessage = 'User not authenticated';
      notifyListeners();
    }
  }

  // Get current user ID from AuthProvider
  String? get currentUserId => _authProvider?.currentUserId;

  InboxProvider() {
    // Don't load chats here - wait for auth provider to be set
  }

  @override
  void dispose() {
    // No subscriptions to cancel anymore
    super.dispose();
  }

  String _getUserTypeForApi() {
    if (_authProvider?.userType == null) return 'student';
    if (_authProvider!.userType == UserType.admin) return 'staff';
    return UserModel.userTypeToApiString(_authProvider!.userType!);
  }

  /// Map API other_user_type (student, teacher, guardian, staff) to UserType for chat.
  static UserType _userTypeFromApiString(String? type) {
    if (type == null) return UserType.student;
    switch (type.toLowerCase()) {
      case 'teacher':
      case 'staff':
        return UserType.teacher;
      case 'guardian':
      case 'parent':
        return UserType.guardian;
      case 'student':
        return UserType.student;
      default:
        return UserType.student;
    }
  }

  // Get API user ID (staff_id, student_id, teacher_id, or parent_id) for fl_chat_users
  String? _getApiUserId() {
    if (_authProvider?.currentUser != null) {
      final user = _authProvider!.currentUser!;
      if (user.userType == UserType.guardian) return user.id;
      return user.uid;
    }
    return null;
  }

  // Load all chats for the current user via HTTP API
  Future<void> _loadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final apiUserId = _getApiUserId();
      if (apiUserId == null ||
          _authProvider == null ||
          !_authProvider!.isAuthenticated) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final userType = _getUserTypeForApi();

      // Admins see Support Inbox (all support conversations). Students/teachers see their own connections (including Support).
      final inboxUserId = _authProvider!.userType == UserType.admin
          ? supportUserId
          : apiUserId;
      final inboxUserType = userType;

      debugPrint(
        'InboxProvider: Loading connections for user: $inboxUserId (type: $inboxUserType)',
      );

      // When loading Support inbox (admin), pass requesting_staff_id so only unclaimed or claimed-by-me threads are returned
      final requestingStaffId = _authProvider!.userType == UserType.admin
          ? apiUserId
          : null;

      // Get connections from API
      final result = await MessagesChatRepository.getConnections(
        userId: inboxUserId,
        userType: inboxUserType,
        requestingStaffId: requestingStaffId,
      );

      if (result['success'] != true) {
        final error = result['error'] ?? 'Unknown error';
        _errorMessage = 'Failed to load chats: $error';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final connections =
          result['connections'] as List<Map<String, dynamic>>? ?? [];

      debugPrint('InboxProvider: Found ${connections.length} connections');

      // Convert connections to ChatModel list
      final List<ChatModel> chats = [];
      final currentUserId = _authProvider!.currentUserId;

      for (var conn in connections) {
        try {
          final connectionId = conn['id']?.toString() ?? '';
          final otherUserId = conn['other_user_id']?.toString();
          final otherUserType = conn['other_user_type']?.toString();

          if (otherUserId == null || otherUserId.isEmpty) {
            debugPrint(
              'InboxProvider: Skipping connection $connectionId - no other_user_id',
            );
            continue;
          }

          // Fetch the other user's data from Firestore (or use API name for parents/guardians when Firestore uses uid not id)
          final otherUserNameFromApi = conn['other_user_name']?.toString();
          UserModel? otherUser;
          try {
            final userDoc = await _firestore
                .collection('user')
                .doc(otherUserId)
                .get();
            if (userDoc.exists) {
              otherUser = UserModel.fromFirestore(userDoc);
              if (otherUser.fullName.isEmpty && otherUserNameFromApi != null && otherUserNameFromApi.isNotEmpty) {
                otherUser = UserModel(
                  uid: otherUser.uid,
                  email: otherUser.email,
                  displayName: otherUserNameFromApi,
                  firstName: otherUser.firstName,
                  lastName: otherUser.lastName,
                  phoneNumber: otherUser.phoneNumber,
                  photoUrl: otherUser.photoUrl,
                  userType: otherUser.userType,
                  createdAt: otherUser.createdAt,
                  updatedAt: otherUser.updatedAt,
                  additionalData: otherUser.additionalData,
                );
              }
              debugPrint(
                'InboxProvider: Fetched user data for: ${otherUser.fullName}',
              );
            } else {
              debugPrint(
                'InboxProvider: User document not found for ID: $otherUserId',
              );
              // Create a minimal user model; use API name (e.g. for parents where Firestore doc id is uid not parent id)
              otherUser = UserModel(
                uid: otherUserId,
                email: '',
                displayName: otherUserNameFromApi?.isNotEmpty == true ? otherUserNameFromApi : null,
                userType: InboxProvider._userTypeFromApiString(otherUserType),
              );
            }
          } catch (e) {
            debugPrint('InboxProvider: Error fetching user data: $e');
            otherUser = UserModel(
              uid: otherUserId,
              email: '',
              displayName: otherUserNameFromApi?.isNotEmpty == true ? otherUserNameFromApi : null,
              userType: InboxProvider._userTypeFromApiString(otherUserType),
            );
          }

          // Unread count: messages not read by the current user (from API)
          final unreadCountRaw = conn['unread_count'];
          final unreadCount = unreadCountRaw is int
              ? unreadCountRaw
              : (int.tryParse(unreadCountRaw?.toString() ?? '0') ?? 0);

          // Parse last message
          final lastMessageData = conn['last_message'] as Map<String, dynamic>?;
          String? lastMessage;
          DateTime? lastMessageTime;
          String? lastMessageSenderId;

          if (lastMessageData != null) {
            lastMessage = lastMessageData['message']?.toString();
            lastMessageSenderId = lastMessageData['sender_id']?.toString();

            // Parse timestamp (Unix timestamp in seconds)
            final time = lastMessageData['time'];
            if (time != null) {
              if (time is int) {
                // Time is in seconds, convert to milliseconds
                lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
                  time * 1000,
                );
              } else if (time is String) {
                try {
                  // Try parsing as integer string first
                  final timeInt = int.tryParse(time);
                  if (timeInt != null) {
                    lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
                      timeInt * 1000,
                    );
                  } else {
                    // Try parsing as ISO string
                    lastMessageTime = DateTime.parse(time);
                  }
                } catch (e) {
                  debugPrint('InboxProvider: Error parsing time: $e');
                }
              }
            }

            // Try created_at if time is not available
            if (lastMessageTime == null) {
              final createdAt = lastMessageData['created_at']?.toString();
              if (createdAt != null) {
                try {
                  lastMessageTime = DateTime.parse(createdAt);
                } catch (e) {
                  debugPrint('InboxProvider: Error parsing created_at: $e');
                }
              }
            }
          }

          // Parse created_at for connection
          DateTime? createdAt;
          final connCreatedAt = conn['created_at']?.toString();
          if (connCreatedAt != null) {
            try {
              createdAt = DateTime.parse(connCreatedAt);
            } catch (e) {
              debugPrint(
                'InboxProvider: Error parsing connection created_at: $e',
              );
            }
          }

          // Create ChatModel with current user as user1 and other user as user2
          // Pass otherUserDisplayName from API so parents show name even when Firestore doc id differs (e.g. parent id vs uid)
          final chatModel = ChatModel(
            chatId: connectionId,
            user1Id: currentUserId ?? '',
            user2Id: otherUserId,
            user1: null, // Current user - not needed for display
            user2: otherUser, // Other user - needed for display
            otherUserDisplayName: otherUserNameFromApi?.trim().isNotEmpty == true ? otherUserNameFromApi!.trim() : null,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            lastMessageSenderId: lastMessageSenderId,
            hasUnreadMessages: unreadCount > 0,
            unreadCount: unreadCount,
            createdAt: createdAt,
          );

          chats.add(chatModel);
        } catch (e) {
          debugPrint('InboxProvider: Error processing connection: $e');
        }
      }

      // Sort chats by last message time (most recent first)
      chats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) {
          return 0;
        }
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      _chats = chats;
      _isLoading = false;
      _errorMessage = null;
      debugPrint('InboxProvider: Loaded ${_chats.length} chats');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading chats: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('InboxProvider: Error loading chats: $e');
    }
  }

  // Refresh chats list
  Future<void> refreshChats() async {
    await _loadChats();
  }

  // Search chats by the other user's name or email
  List<ChatModel> searchChats(String query) {
    if (query.isEmpty) return _chats;

    final currentUserId = _authProvider?.currentUserId;
    if (currentUserId == null) return [];

    final lowerQuery = query.toLowerCase();
    return _chats.where((chat) {
      final otherUser = chat.getOtherUser(currentUserId);
      if (otherUser == null) return false;
      return otherUser.fullName.toLowerCase().contains(lowerQuery) ||
          otherUser.email.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
