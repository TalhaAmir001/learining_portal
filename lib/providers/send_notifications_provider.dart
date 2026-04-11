import 'package:flutter/foundation.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/domain/notice_board_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';

/// Provider for send_notifications (dashboard notice board from API).
class SendNotificationsProvider with ChangeNotifier {
  AuthProvider? _authProvider;

  List<NoticeBoardModel> _notices = [];
  List<NoticeBoardModel> _unreadNotices = [];
  bool _isLoading = false;
  bool _isLoadingUnread = false;
  String? _errorMessage;

  List<NoticeBoardModel> get notices => _notices;
  List<NoticeBoardModel> get unreadNotices => _unreadNotices;
  bool get isLoading => _isLoading;
  bool get isLoadingUnread => _isLoadingUnread;
  String? get errorMessage => _errorMessage;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      loadNotices();
      loadUnreadNotices();
    } else {
      _notices = [];
      _unreadNotices = [];
      _isLoading = false;
      _isLoadingUnread = false;
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
    int? studentId;
    String? sessionId;
    int? staffId;
    final uid = _authProvider?.currentUser?.uid;
    if (userType == UserType.student) {
      if (uid != null && uid.isNotEmpty) {
        studentId = int.tryParse(uid);
      }
      final s = _authProvider?.currentUser?.additionalData?['session_id'];
      sessionId = s?.toString();
    } else if (userType == UserType.teacher || userType == UserType.admin) {
      if (uid != null && uid.isNotEmpty) {
        staffId = int.tryParse(uid);
      }
    }
    final roleIdsCsv = (userType == UserType.teacher || userType == UserType.admin)
        ? UserModel.staffNoticeRoleIdsCsv(
            _authProvider?.currentUser?.additionalData,
          )
        : null;
    final list = await NoticeBoardRepository.getSendNotifications(
      userType: apiUserType,
      studentId: studentId,
      sessionId: sessionId,
      staffId: staffId,
      roleIdsCsv: roleIdsCsv,
    );

    _notices = list.map(NoticeBoardModel.fromSendNotification).toList()
      ..sort((a, b) {
        final da = a.publishDate ?? a.date ?? a.createdAt ?? DateTime(0);
        final db = b.publishDate ?? b.date ?? b.createdAt ?? DateTime(0);
        return db.compareTo(da);
      });
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Load only unread notices (for dashboard notice box). Uses get_unread_notifications API.
  Future<void> loadUnreadNotices() async {
    final userType = _authProvider?.userType;
    if (userType == null) {
      _unreadNotices = [];
      _isLoadingUnread = false;
      notifyListeners();
      return;
    }

    _isLoadingUnread = true;
    notifyListeners();

    final apiUserType = userTypeToApiString(userType);
    int? studentId;
    String? sessionId;
    int? userId;
    if (userType == UserType.student) {
      final uid = _authProvider?.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        studentId = int.tryParse(uid);
      }
      final s = _authProvider?.currentUser?.additionalData?['session_id'];
      sessionId = s?.toString();
    } else {
      final uid = _authProvider?.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        userId = int.tryParse(uid);
      }
    }

    final unreadRoleIdsCsv =
        (userType == UserType.teacher || userType == UserType.admin)
            ? UserModel.staffNoticeRoleIdsCsv(
                _authProvider?.currentUser?.additionalData,
              )
            : null;

    final list = await NoticeBoardRepository.getUnreadNotifications(
      userType: apiUserType,
      studentId: studentId,
      sessionId: sessionId,
      userId: userId,
      roleIdsCsv: unreadRoleIdsCsv,
    );

    _unreadNotices = list.map(NoticeBoardModel.fromSendNotification).toList()
      ..sort((a, b) {
        final da = a.publishDate ?? a.date ?? a.createdAt ?? DateTime(0);
        final db = b.publishDate ?? b.date ?? b.createdAt ?? DateTime(0);
        return db.compareTo(da);
      });
    _isLoadingUnread = false;
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
