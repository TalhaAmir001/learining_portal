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
  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastLoadedAt;
  int _loadGeneration = 0;
  bool _loadInProgress = false;
  bool _pendingRefresh = false;
  final Map<String, UserModel> _userProfileCache = {};

  static const _cacheTtl = Duration(seconds: 30);

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Cached Firestore profile for a chat partner (first/last name, photo).
  UserModel? cachedUserProfile(String userId) => _userProfileCache[userId];

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      final shouldReload = _chats.isEmpty ||
          _lastLoadedAt == null ||
          DateTime.now().difference(_lastLoadedAt!) > _cacheTtl;
      if (shouldReload) {
        _loadChats();
      }
    } else {
      _isInitialLoading = false;
      _isRefreshing = false;
      _errorMessage = 'User not authenticated';
      notifyListeners();
    }
  }

  String? get currentUserId => _authProvider?.currentUserId;

  InboxProvider();

  String _getUserTypeForApi() {
    if (_authProvider?.userType == null) return 'student';
    if (_authProvider!.userType == UserType.admin) return 'staff';
    return UserModel.userTypeToApiString(_authProvider!.userType!);
  }

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

  String? _getApiUserId() {
    if (_authProvider?.currentUser != null) {
      final user = _authProvider!.currentUser!;
      if (user.userType == UserType.guardian) return user.id;
      return user.uid;
    }
    return null;
  }

  void _seedProfileCacheFromChats() {
    for (final chat in _chats) {
      final user = chat.user2;
      if (user != null) _rememberUserProfile(user);
    }
  }

  void _rememberUserProfile(UserModel user) {
    if (!user.hasStructuredName &&
        (user.photoUrl == null || user.photoUrl!.isEmpty)) {
      return;
    }
    final existing = _userProfileCache[user.uid];
    if (existing == null) {
      _userProfileCache[user.uid] = user;
      return;
    }
    _userProfileCache[user.uid] = UserModel(
      uid: user.uid,
      email: user.email.isNotEmpty ? user.email : existing.email,
      displayName: user.hasStructuredName
          ? user.displayName
          : (existing.displayName ?? user.displayName),
      firstName: user.firstName ?? existing.firstName,
      lastName: user.lastName ?? existing.lastName,
      phoneNumber: user.phoneNumber ?? existing.phoneNumber,
      photoUrl: user.photoUrl ?? existing.photoUrl,
      userType: user.userType,
      createdAt: user.createdAt ?? existing.createdAt,
      updatedAt: user.updatedAt ?? existing.updatedAt,
      additionalData: user.additionalData ?? existing.additionalData,
    );
  }

  UserModel _mergeWithCachedProfile(
    UserModel apiUser, {
    String? apiDisplayName,
  }) {
    final cached = _userProfileCache[apiUser.uid];
    if (cached == null || !cached.hasStructuredName) return apiUser;
    return UserModel(
      uid: cached.uid,
      email: cached.email.isNotEmpty ? cached.email : apiUser.email,
      displayName: cached.displayName ?? apiDisplayName ?? apiUser.displayName,
      firstName: cached.firstName,
      lastName: cached.lastName,
      phoneNumber: cached.phoneNumber ?? apiUser.phoneNumber,
      photoUrl: cached.photoUrl ?? apiUser.photoUrl,
      userType: cached.userType,
      createdAt: cached.createdAt ?? apiUser.createdAt,
      updatedAt: cached.updatedAt ?? apiUser.updatedAt,
      additionalData: cached.additionalData ?? apiUser.additionalData,
    );
  }

  Future<void> _loadChats() async {
    if (_loadInProgress) {
      _pendingRefresh = true;
      return;
    }
    _loadInProgress = true;
    final generation = ++_loadGeneration;

    final isInitial = _chats.isEmpty;
    if (isInitial) {
      _isInitialLoading = true;
    } else {
      _isRefreshing = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final apiUserId = _getApiUserId();
      if (apiUserId == null ||
          _authProvider == null ||
          !_authProvider!.isAuthenticated) {
        _errorMessage = 'User not authenticated';
        _isInitialLoading = false;
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      final userType = _getUserTypeForApi();
      final inboxUserId = _authProvider!.userType == UserType.admin
          ? supportUserId
          : apiUserId;
      final inboxUserType = userType;
      final requestingStaffId = _authProvider!.userType == UserType.admin
          ? apiUserId
          : null;

      final result = await MessagesChatRepository.getConnections(
        userId: inboxUserId,
        userType: inboxUserType,
        requestingStaffId: requestingStaffId,
      );

      if (generation != _loadGeneration) return;

      if (result['success'] != true) {
        final error = result['error'] ?? 'Unknown error';
        if (_chats.isEmpty) {
          _errorMessage = 'Failed to load chats: $error';
        }
        _isInitialLoading = false;
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      final connections =
          result['connections'] as List<Map<String, dynamic>>? ?? [];
      final currentUserId = _authProvider!.currentUserId;
      _seedProfileCacheFromChats();
      var chats = _buildChatsFromConnections(connections, currentUserId);

      // First open: resolve Firestore names before showing the list (avoids username flash).
      if (isInitial) {
        chats = await _enrichChatsWithFirestoreProfiles(chats, generation);
      }

      if (generation != _loadGeneration) return;

      _chats = chats;
      _lastLoadedAt = DateTime.now();
      _isInitialLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();

      if (!isInitial) {
        unawaited(_refreshProfilesInBackground(generation));
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      if (_chats.isEmpty) {
        _errorMessage = 'Error loading chats: ${e.toString()}';
      }
      _isInitialLoading = false;
      _isRefreshing = false;
      notifyListeners();
      debugPrint('InboxProvider: Error loading chats: $e');
    } finally {
      _loadInProgress = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(_loadChats());
      }
    }
  }

  List<ChatModel> _buildChatsFromConnections(
    List<Map<String, dynamic>> connections,
    String? currentUserId,
  ) {
    final List<ChatModel> chats = [];

    for (var conn in connections) {
      try {
        final connectionId = conn['id']?.toString() ?? '';
        final otherUserId = conn['other_user_id']?.toString();
        final otherUserType = conn['other_user_type']?.toString();

        if (otherUserId == null || otherUserId.isEmpty) continue;

        final otherUserNameFromApi = conn['other_user_name']?.toString();
        final apiUser = UserModel(
          uid: otherUserId,
          email: '',
          displayName: otherUserNameFromApi?.isNotEmpty == true
              ? otherUserNameFromApi
              : null,
          userType: _userTypeFromApiString(otherUserType),
        );
        final otherUser = _mergeWithCachedProfile(
          apiUser,
          apiDisplayName: otherUserNameFromApi,
        );

        final unreadCountRaw = conn['unread_count'];
        final unreadCount = unreadCountRaw is int
            ? unreadCountRaw
            : (int.tryParse(unreadCountRaw?.toString() ?? '0') ?? 0);

        final lastMessageData = conn['last_message'] as Map<String, dynamic>?;
        String? lastMessage;
        DateTime? lastMessageTime;
        String? lastMessageSenderId;

        if (lastMessageData != null) {
          lastMessage = lastMessageData['message']?.toString();
          lastMessageSenderId = lastMessageData['sender_id']?.toString();

          final time = lastMessageData['time'];
          if (time != null) {
            if (time is int) {
              lastMessageTime =
                  DateTime.fromMillisecondsSinceEpoch(time * 1000);
            } else if (time is String) {
              final timeInt = int.tryParse(time);
              if (timeInt != null) {
                lastMessageTime =
                    DateTime.fromMillisecondsSinceEpoch(timeInt * 1000);
              } else {
                try {
                  lastMessageTime = DateTime.parse(time);
                } catch (_) {}
              }
            }
          }

          if (lastMessageTime == null) {
            final createdAt = lastMessageData['created_at']?.toString();
            if (createdAt != null) {
              try {
                lastMessageTime = DateTime.parse(createdAt);
              } catch (_) {}
            }
          }
        }

        DateTime? createdAt;
        final connCreatedAt = conn['created_at']?.toString();
        if (connCreatedAt != null) {
          try {
            createdAt = DateTime.parse(connCreatedAt);
          } catch (_) {}
        }

        chats.add(
          ChatModel(
            chatId: connectionId,
            user1Id: currentUserId ?? '',
            user2Id: otherUserId,
            user1: null,
            user2: otherUser,
            otherUserDisplayName:
                otherUserNameFromApi?.trim().isNotEmpty == true
                    ? otherUserNameFromApi!.trim()
                    : null,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            lastMessageSenderId: lastMessageSenderId,
            hasUnreadMessages: unreadCount > 0,
            unreadCount: unreadCount,
            createdAt: createdAt,
          ),
        );
      } catch (e) {
        debugPrint('InboxProvider: Error processing connection: $e');
      }
    }

    chats.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    return chats;
  }

  Future<List<ChatModel>> _enrichChatsWithFirestoreProfiles(
    List<ChatModel> chats,
    int generation,
  ) async {
    if (generation != _loadGeneration || chats.isEmpty) return chats;

    final userIds = chats
        .map((chat) => chat.user2Id)
        .where((id) => id.isNotEmpty)
        .where((id) {
          final cached = _userProfileCache[id];
          return cached == null || !cached.hasStructuredName;
        })
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return _applyCachedProfilesToChats(chats);
    }

    try {
      final docs = await Future.wait(
        userIds.map((id) => _firestore.collection('user').doc(id).get()),
      );

      if (generation != _loadGeneration) return chats;

      for (var i = 0; i < userIds.length; i++) {
        final doc = docs[i];
        if (!doc.exists) continue;
        _rememberUserProfile(UserModel.fromFirestore(doc));
      }

      return _applyCachedProfilesToChats(chats);
    } catch (e) {
      debugPrint('InboxProvider: Firestore profile enrichment failed: $e');
      return chats;
    }
  }

  List<ChatModel> _applyCachedProfilesToChats(List<ChatModel> chats) {
    return chats.map((chat) {
      final cached = _userProfileCache[chat.user2Id];
      if (cached == null || !cached.hasStructuredName) return chat;

      final apiName = chat.otherUserDisplayName;
      final mergedUser = UserModel(
        uid: cached.uid,
        email: cached.email.isNotEmpty ? cached.email : (chat.user2?.email ?? ''),
        displayName: cached.displayName ?? apiName ?? chat.user2?.displayName,
        firstName: cached.firstName,
        lastName: cached.lastName,
        phoneNumber: cached.phoneNumber ?? chat.user2?.phoneNumber,
        photoUrl: cached.photoUrl ?? chat.user2?.photoUrl,
        userType: cached.userType,
        createdAt: cached.createdAt ?? chat.user2?.createdAt,
        updatedAt: cached.updatedAt ?? chat.user2?.updatedAt,
        additionalData: cached.additionalData ?? chat.user2?.additionalData,
      );

      return chat.copyWith(user2: mergedUser);
    }).toList();
  }

  Future<void> _refreshProfilesInBackground(int generation) async {
    if (_chats.isEmpty || generation != _loadGeneration) return;

    final enriched = await _enrichChatsWithFirestoreProfiles(
      _chats,
      generation,
    );
    if (generation != _loadGeneration) return;

    final changed = enriched.length != _chats.length ||
        enriched.asMap().entries.any(
              (e) => e.value.user2?.uid != _chats[e.key].user2?.uid ||
                  e.value.user2?.fullName != _chats[e.key].user2?.fullName ||
                  e.value.user2?.photoUrl != _chats[e.key].user2?.photoUrl,
            );

    if (changed) {
      _chats = enriched;
      notifyListeners();
    }
  }

  Future<void> refreshChats() async {
    await _loadChats();
  }

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
