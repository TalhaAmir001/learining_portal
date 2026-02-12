import 'package:flutter/foundation.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/network/domain/notice_board_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';

/// Provider for send_notifications (dashboard notice board from API).
class SendNotificationsProvider with ChangeNotifier {
  AuthProvider? _authProvider;

  List<NoticeBoardModel> _notices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NoticeBoardModel> get notices => _notices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      loadNotices();
    } else {
      _notices = [];
      _isLoading = false;
      _errorMessage = 'Not authenticated';
      notifyListeners();
    }
  }

  /// Map UserType to API user_type for visibility and read_notifications.
  static String userTypeToApiString(UserType? userType) {
    if (userType == null) return 'staff';
    switch (userType) {
      case UserType.student:
        return 'student';
      case UserType.guardian:
        return 'parent';
      case UserType.teacher:
      case UserType.admin:
        return 'staff';
    }
  }

  Future<void> loadNotices() async {
    final userType = _authProvider?.userType;
    if (userType == null) {
      _notices = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final apiUserType = userTypeToApiString(userType);
    final list = await NoticeBoardRepository.getSendNotifications(
      userType: apiUserType,
    );

    _notices = list
        .map(NoticeBoardModel.fromSendNotification)
        .toList()
      ..sort((a, b) {
        final da = a.publishDate ?? a.date ?? a.createdAt ?? DateTime(0);
        final db = b.publishDate ?? b.date ?? b.createdAt ?? DateTime(0);
        return db.compareTo(da);
      });
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Call after user opens notice detail so we can record read. Returns success.
  Future<bool> markAsRead(int notificationId) async {
    final auth = _authProvider;
    final userType = auth?.userType;
    final uid = auth?.currentUser?.uid;
    if (userType == null || uid == null) return false;

    final apiUserType = userTypeToApiString(userType);
    final ok = await NoticeBoardRepository.markNotificationAsRead(
      notificationId: notificationId,
      userType: apiUserType,
      userId: uid,
    );
    return ok;
  }
}
