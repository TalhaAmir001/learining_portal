import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/utils/constants.dart';
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

  // Load all users from Firestore
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

      // Listen to real-time updates from the 'user' collection
      _firestore
          .collection('user')
          .snapshots()
          .listen(
            (snapshot) {
              _users = snapshot.docs
                  .map((doc) => UserModel.fromFirestore(doc))
                  .where(
                    (user) => user.uid != currentUserId,
                  ) // Exclude current user
                  .toList();

              // Sort users alphabetically by full name
              _users.sort((a, b) => a.fullName.compareTo(b.fullName));

              _isLoading = false;
              _errorMessage = null;
              notifyListeners();
            },
            onError: (error) {
              _errorMessage = 'Error loading users: ${error.toString()}';
              _isLoading = false;
              notifyListeners();
              debugPrint('Error loading users: $error');
            },
          );
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
