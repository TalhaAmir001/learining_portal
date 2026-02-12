import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notice_model.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';

class NoticeBoardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = firestore;
  AuthProvider? _authProvider;

  List<NoticeModel> _notices = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _noticesSubscription;

  List<NoticeModel> get notices => _notices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Set auth provider (called from widget that has access to context)
  void setAuthProvider(AuthProvider authProvider) {
    debugPrint('NoticeBoardProvider: setAuthProvider called. Authenticated: ${authProvider.isAuthenticated}');
    _authProvider = authProvider;
    // Load notices when auth provider is set
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      debugPrint('NoticeBoardProvider: Loading notices...');
      _loadNotices();
    } else {
      debugPrint('NoticeBoardProvider: Not authenticated, skipping notice load');
      _isLoading = false;
      _errorMessage = 'User not authenticated';
      notifyListeners();
    }
  }

  // Get current user ID from AuthProvider
  String? get currentUserId => _authProvider?.currentUserId;

  NoticeBoardProvider() {
    // Don't load notices here - wait for auth provider to be set
  }

  void dispose() {
    _noticesSubscription?.cancel();
    super.dispose();
  }

  // Load all notices from Firestore
  Future<void> _loadNotices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = _authProvider?.currentUserId;
      if (currentUserId == null || _authProvider == null || !_authProvider!.isAuthenticated) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Cancel existing subscription
      await _noticesSubscription?.cancel();

      // Get user type from auth provider
      final userType = _authProvider!.currentUser?.userType;
      final userTypeString = userType != null ? _userTypeToString(userType) : null;

      // Listen to real-time updates from the 'notices' collection
      // Filter by user type if applicable, or show all if no filter
      Query query = _firestore
          .collection('notices')
          .orderBy('isPinned', descending: true) // Pinned notices first
          .orderBy('createdAt', descending: true); // Then by creation date

      // If user type is specified, filter notices that are either:
      // 1. Not targeted (targetUserTypes is null/empty) - public notices
      // 2. Targeted to this user's type
      // Note: Firestore doesn't support array-contains with OR, so we'll filter client-side
      // For better performance, you might want to structure your Firestore queries differently

      _noticesSubscription = query.snapshots().listen(
        (snapshot) {
          debugPrint('NoticeBoardProvider: Received snapshot with ${snapshot.docs.length} notices');
          _processNoticesSnapshot(snapshot, userTypeString);
        },
        onError: (error) {
          debugPrint('NoticeBoardProvider: Subscription error: $error');
          _errorMessage = 'Error loading notices: ${error.toString()}';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Error loading notices: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('NoticeBoardProvider: Error loading notices: $e');
    }
  }

  // Process notices snapshot
  void _processNoticesSnapshot(QuerySnapshot snapshot, String? userTypeString) {
    try {
      _notices = snapshot.docs
          .map((doc) => NoticeModel.fromFirestore(doc))
          .where((notice) {
            // Filter by user type if notice has targetUserTypes
            if (notice.targetUserTypes != null && notice.targetUserTypes!.isNotEmpty) {
              // If user type is not specified, don't show targeted notices
              if (userTypeString == null) return false;
              // Show notice if user's type is in targetUserTypes
              return notice.targetUserTypes!.contains(userTypeString);
            }
            // Show public notices (no targetUserTypes) to everyone
            return true;
          })
          .toList();

      // Sort: pinned first, then by creation date
      _notices.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      _isLoading = false;
      _errorMessage = null;
      debugPrint('NoticeBoardProvider: Processed ${_notices.length} notices');
      notifyListeners();
    } catch (e) {
      debugPrint('NoticeBoardProvider: Error processing notices: $e');
      _errorMessage = 'Error processing notices: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper to convert UserType enum to string
  String _userTypeToString(dynamic userType) {
    return userType.toString().split('.').last;
  }

  // Refresh notices list
  Future<void> refreshNotices() async {
    await _loadNotices();
  }

  // Search notices by title or content
  List<NoticeModel> searchNotices(String query) {
    if (query.isEmpty) return _notices;

    final lowerQuery = query.toLowerCase();
    return _notices.where((notice) {
      return notice.title.toLowerCase().contains(lowerQuery) ||
          notice.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
