import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

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

  StreamSubscription<QuerySnapshot>? _user1Subscription;
  StreamSubscription<QuerySnapshot>? _user2Subscription;
  final Map<String, ChatModel> _chatsMap = {};
  final Map<String, bool> _chatSubscriptionMap =
      {}; // Track which subscription each chat belongs to
  bool _user1SnapshotProcessed = false;
  bool _user2SnapshotProcessed = false;

  void dispose() {
    _user1Subscription?.cancel();
    _user2Subscription?.cancel();
  }

  // Load all chats for the current user
  Future<void> _loadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = _authProvider?.currentUserId;
      if (currentUserId == null ||
          _authProvider == null ||
          !_authProvider!.isAuthenticated) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Cancel existing subscriptions
      await _user1Subscription?.cancel();
      await _user2Subscription?.cancel();
      _chatsMap.clear();
      _chatSubscriptionMap.clear();
      _user1SnapshotProcessed = false;
      _user2SnapshotProcessed = false;

      // Listen to real-time updates from the 'chats' collection
      // Set a timeout to ensure loading doesn't stay true forever
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading &&
            (!_user1SnapshotProcessed || !_user2SnapshotProcessed)) {
          debugPrint('Timeout: Forcing loading to complete');
          _user1SnapshotProcessed = true;
          _user2SnapshotProcessed = true;
          _isLoading = false;
          if (_errorMessage == null) {
            _errorMessage = 'Timeout waiting for chat data';
          }
          notifyListeners();
        }
      });

      // Get chats where current user is user1
      _user1Subscription = _firestore
          .collection('chats')
          .where('user1Id', isEqualTo: currentUserId)
          .snapshots()
          .listen(
            (snapshot) async {
              debugPrint(
                'User1 subscription received snapshot with ${snapshot.docs.length} docs',
              );
              await _processChatsSnapshot(
                snapshot,
                currentUserId,
                isUser1: true,
              );
            },
            onError: (error) {
              debugPrint('User1 subscription error: $error');
              _errorMessage = 'Error loading chats: ${error.toString()}';
              _user1SnapshotProcessed = true;
              if (_user1SnapshotProcessed && _user2SnapshotProcessed) {
                _isLoading = false;
                notifyListeners();
              }
            },
          );

      // Get chats where current user is user2
      _user2Subscription = _firestore
          .collection('chats')
          .where('user2Id', isEqualTo: currentUserId)
          .snapshots()
          .listen(
            (snapshot) async {
              debugPrint(
                'User2 subscription received snapshot with ${snapshot.docs.length} docs',
              );
              await _processChatsSnapshot(
                snapshot,
                currentUserId,
                isUser1: false,
              );
            },
            onError: (error) {
              debugPrint('User2 subscription error: $error');
              _errorMessage = 'Error loading chats: ${error.toString()}';
              _user2SnapshotProcessed = true;
              if (_user1SnapshotProcessed && _user2SnapshotProcessed) {
                _isLoading = false;
                notifyListeners();
              }
            },
          );
    } catch (e) {
      _errorMessage = 'Error loading chats: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading chats: $e');
    }
  }

  // Process chats snapshot and fetch user data
  Future<void> _processChatsSnapshot(
    QuerySnapshot snapshot,
    String currentUserId, {
    required bool isUser1,
  }) async {
    try {
      debugPrint(
        'Processing ${isUser1 ? "user1" : "user2"} snapshot with ${snapshot.docs.length} documents',
      );

      // Mark this subscription as processed
      if (isUser1) {
        _user1SnapshotProcessed = true;
      } else {
        _user2SnapshotProcessed = true;
      }

      // Process document changes (added, modified, removed)
      // If docChanges is empty but we have docs, process all docs as added
      // This handles the initial snapshot case
      final changesToProcess = snapshot.docChanges.isNotEmpty
          ? snapshot.docChanges
          : snapshot.docs.map((doc) {
              // Create a synthetic DocumentChange for initial load
              return _createDocumentChange(doc, snapshot.docs.indexOf(doc));
            }).toList();

      for (var change in changesToProcess) {
        final doc = change.doc;
        final chatId = doc.id;

        if (change.type == DocumentChangeType.removed) {
          // Remove chat if it belongs to this subscription
          if (_chatSubscriptionMap[chatId] == isUser1) {
            _chatsMap.remove(chatId);
            _chatSubscriptionMap.remove(chatId);
            debugPrint('Removed chat: $chatId');
          }
        } else {
          // Added or modified
          final chat = ChatModel.fromFirestore(doc);
          debugPrint(
            'Processing chat: $chatId, user1Id: ${chat.user1Id}, user2Id: ${chat.user2Id}',
          );

          // Determine which user is the other user
          final otherUserId = chat.getOtherUserId(currentUserId);
          if (otherUserId.isEmpty) {
            debugPrint(
              'Warning: Could not determine other user ID for chat $chatId. CurrentUserId: $currentUserId',
            );
            continue;
          }

          // Fetch the other user's data
          UserModel? otherUser;
          try {
            final userDoc = await _firestore
                .collection('user')
                .doc(otherUserId)
                .get();
            if (userDoc.exists) {
              otherUser = UserModel.fromFirestore(userDoc);
              debugPrint('Fetched user data for: ${otherUser.fullName}');
            } else {
              debugPrint(
                'Warning: User document not found for ID: $otherUserId',
              );
            }
          } catch (e) {
            debugPrint('Error fetching user data: $e');
          }

          // Update chat with correct user data
          ChatModel finalChat;
          if (isUser1) {
            finalChat = chat.copyWith(user2: otherUser);
          } else {
            finalChat = chat.copyWith(user1: otherUser);
          }

          _chatsMap[chatId] = finalChat;
          _chatSubscriptionMap[chatId] = isUser1;
        }
      }

      // Convert map to list
      _chats = _chatsMap.values.toList();
      debugPrint('Total chats after processing: ${_chats.length}');

      // Sort chats by last message time (most recent first)
      _chats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) {
          return 0;
        }
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      // Only set loading to false after both subscriptions have been processed
      if (_user1SnapshotProcessed && _user2SnapshotProcessed) {
        _isLoading = false;
        _errorMessage = null;
        debugPrint(
          'Both snapshots processed. Loading complete. Total chats: ${_chats.length}',
        );
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing chats: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Error processing chats: ${e.toString()}';
      // Still mark as processed to avoid infinite loading
      if (isUser1) {
        _user1SnapshotProcessed = true;
      } else {
        _user2SnapshotProcessed = true;
      }
      if (_user1SnapshotProcessed && _user2SnapshotProcessed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Helper to create a DocumentChange for initial load
  DocumentChange _createDocumentChange(DocumentSnapshot doc, int index) {
    // Create a minimal DocumentChange-like object
    return _SyntheticDocumentChange(doc, index);
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

// Helper class to simulate DocumentChange for initial load
class _SyntheticDocumentChange implements DocumentChange {
  final DocumentSnapshot _doc;
  final int _newIndex;

  _SyntheticDocumentChange(this._doc, this._newIndex);

  @override
  DocumentChangeType get type => DocumentChangeType.added;

  @override
  DocumentSnapshot get doc => _doc;

  @override
  int get oldIndex => -1;

  @override
  int get newIndex => _newIndex;
}
