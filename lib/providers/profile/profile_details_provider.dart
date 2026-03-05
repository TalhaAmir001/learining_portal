import 'package:flutter/foundation.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';

/// Provider for the profile screen. Exposes the current user and syncs from [AuthProvider].
class ProfileProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get hasUser => _user != null;

  /// Sync profile from auth. Call when opening profile or when auth changes.
  void loadFromAuth(AuthProvider authProvider) {
    _isLoading = true;
    notifyListeners();
    _user = authProvider.currentUser;
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
