import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import '../../providers/auth_provider.dart';

class MembersProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = firestore;
  AuthProvider? _authProvider;

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Single "Support" user for students/teachers (Shared Inbox). Any admin can reply.
  static UserModel get supportUser => UserModel(
        uid: supportUserId,
        email: '',
        displayName: 'Support',
        firstName: 'Support',
        lastName: '',
        userType: UserType.admin,
      );

  // Set auth provider (called from widget that has access to context)
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    // Reload users when auth provider is set
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      _loadUsers();
    }
  }

  // Get current user ID from AuthProvider
  String? get currentUserId => _authProvider?.currentUserId;

  MembersProvider() {
    // Don't load users in constructor - wait for auth provider to be set
  }

  // Load users: students/teachers see only Support; admins see Support Inbox (list of support conversation partners)
  Future<void> _loadUsers() async {
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

      final userType = _authProvider!.userType;

      // Students and teachers: show only Support (Single Support User / Shared Inbox)
      if (userType == UserType.student || userType == UserType.teacher) {
        _users = [supportUser];
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      // Admins: load Support Inbox — list of users who have support conversations (other side of Support connections)
      if (userType == UserType.admin) {
        final result = await MessagesChatRepository.getConnections(
          userId: supportUserId,
          userType: 'staff',
        );
        if (result['success'] != true) {
          _errorMessage = result['error']?.toString() ?? 'Failed to load support inbox';
          _isLoading = false;
          notifyListeners();
          return;
        }
        final connections = result['connections'] as List<Map<String, dynamic>>? ?? [];
        final List<UserModel> supportPartners = [];
        for (var conn in connections) {
          final otherUserId = conn['other_user_id']?.toString();
          final otherUserType = conn['other_user_type']?.toString();
          if (otherUserId == null || otherUserId.isEmpty) continue;
          UserModel? otherUser;
          try {
            final userDoc = await _firestore.collection('user').doc(otherUserId).get();
            if (userDoc.exists) {
              otherUser = UserModel.fromFirestore(userDoc);
            } else {
              otherUser = UserModel(
                uid: otherUserId,
                email: '',
                userType: otherUserType == 'staff' ? UserType.teacher : UserType.student,
              );
            }
          } catch (_) {
            otherUser = UserModel(
              uid: otherUserId,
              email: '',
              userType: otherUserType == 'staff' ? UserType.teacher : UserType.student,
            );
          }
          supportPartners.add(otherUser);
        }
        supportPartners.sort((a, b) => a.fullName.compareTo(b.fullName));
        _users = supportPartners;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      // Guardian: same as student — show only Support
      _users = [supportUser];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading users: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading users: $e');
    }
  }

  // Refresh users list
  Future<void> refreshUsers() async {
    await _loadUsers();
  }

  // Search users by name or email
  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return _users;

    final lowerQuery = query.toLowerCase();
    return _users.where((user) {
      return user.fullName.toLowerCase().contains(lowerQuery) ||
          user.email.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
