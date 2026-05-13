import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/network/data_models/auth/admin_data_model.dart';
import 'package:learining_portal/network/data_models/auth/user_data_model.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/domain/parent_link_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:learining_portal/network/domain/auth_repository.dart';
import 'package:learining_portal/services/notification_service.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/utils/web_socket_client.dart';

enum UserType { student, guardian, teacher, admin }

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _userIdKey = 'current_user_id';
  SharedPreferences? _prefs;

  bool _isLoading = false;
  bool _isInitializing = true; // Track initial auth state check
  bool _isAuthenticated = false;
  String? _errorMessage;
  UserModel? _currentUser;
  String? _currentUserId; // Store the document ID for Firestore

  // WebSocket client for real-time messaging
  WebSocketClient? _wsClient;
  bool _isWebSocketConnected = false;
  bool _shouldMaintainConnection = true; // Flag to maintain connection

  // ── Parent self-link children ─────────────────────────────────────────────
  // When the logged-in user is a guardian, these track the children they are
  // linked to in the portal and the one currently selected as "active". The
  // active id is mirrored to the server (`users.active_child_id`) and to
  // SharedPreferences so a relaunch is offline-friendly.
  List<ParentChild> _linkedChildren = const [];
  int? _selectedChildId;
  bool _isLoadingLinkedChildren = false;
  String? _linkedChildrenError;

  static const String _selectedChildIdKeyPrefix = 'guardian_selected_child_id_';
  // Linked-children cache (JSON list of ParentChild). Hydrated on app
  // restart so the dashboard picker shows the previously-known active child
  // *instantly* instead of waiting for the network refresh to land.
  static const String _linkedChildrenCacheKeyPrefix = 'guardian_linked_children_';

  // Callback for when new messages are received
  Function(Map<String, dynamic>)? onNewMessageReceived;

  /// Callback for when a new notice is broadcast (notice board); app can refresh notice list.
  Function(Map<String, dynamic>)? onNewNoticeReceived;

  // Constructor for normal initialization
  AuthProvider() {
    // Initialize SharedPreferences and check auth state asynchronously
    // Don't await in constructor to avoid blocking
    _initSharedPreferences();
  }

  // Named constructor for initialization with pre-loaded state
  // Used when auth state is checked in main.dart before app starts
  AuthProvider.withInitialState({
    required bool isAuthenticated,
    UserModel? currentUser,
    String? currentUserId,
    SharedPreferences? prefs,
  }) {
    _isInitializing = false;
    _isAuthenticated = isAuthenticated;
    _currentUser = currentUser;
    _currentUserId = currentUserId;
    _prefs = prefs;

    // If prefs is null, initialize it asynchronously (shouldn't happen but safety check)
    if (_prefs == null) {
      SharedPreferences.getInstance()
          .then((prefs) {
            _prefs = prefs;
            debugPrint(
              'SharedPreferences initialized in withInitialState fallback',
            );
          })
          .catchError((e) {
            debugPrint(
              'Error initializing SharedPreferences in withInitialState: $e',
            );
          });
    }

    // Initialize WebSocket if user is already authenticated
    if (isAuthenticated && currentUser != null) {
      _shouldMaintainConnection = true;
      // Initialize WebSocket asynchronously after a short delay to ensure app is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _initializeWebSocket().catchError((error) {
          debugPrint(
            'Error initializing WebSocket in withInitialState: $error',
          );
          // Don't fail initialization if WebSocket connection fails
        });
      });

      // Guardian fast-path hydration: without this the dashboard picker
      // and the chat active-child bar both stay empty until a manual
      // refresh, because checkAuthState() is skipped on this code path.
      if (currentUser.userType == UserType.guardian) {
        _hydrateLinkedChildrenFromCacheThenRefresh();
      }
    }
  }

  /// Restore the guardian's linked-children list + selected child from the
  /// SharedPreferences cache for instant first paint, then kick a background
  /// refresh so server state wins shortly after. Called from
  /// [AuthProvider.withInitialState] only — the regular constructor path
  /// goes through [checkAuthState] which already triggers the refresh.
  void _hydrateLinkedChildrenFromCacheThenRefresh() {
    final parentId = _guardianParentId;
    if (parentId == null) return;

    final cached = _loadLinkedChildrenFromPrefsSync(parentId);
    if (cached.isNotEmpty) {
      _linkedChildren = cached;
      final savedId = _loadSelectedChildIdFromPrefsSync(parentId);
      if (savedId != null && cached.any((c) => c.studentId == savedId)) {
        _selectedChildId = savedId;
      } else if (cached.length == 1) {
        _selectedChildId = cached.first.studentId;
      }
      // No notifyListeners here — the provider is being constructed and
      // listeners haven't subscribed yet. First paint reads the seeded
      // fields directly.
    }

    // Background refresh: same staggered delay as the WebSocket so we
    // don't compete with first-frame work.
    Future.delayed(const Duration(milliseconds: 800), () {
      refreshLinkedChildren().catchError((Object e) {
        debugPrint(
          'Error refreshing linked children in withInitialState: $e',
        );
      });
    });
  }

  bool get isInitializing => _isInitializing;
  bool get isSuperAdmin =>
      _currentUser?.additionalData?['is_superadmin'] == true;

  /// Returns a usable student_id for student-only APIs.
  /// For SuperAdmin, this uses [superAdminImpersonateStudentId].
  int? effectiveStudentId() {
    if (isSuperAdmin) {
      return superAdminImpersonateStudentId > 0
          ? superAdminImpersonateStudentId
          : null;
    }
    if (userType != UserType.student) return null;
    final raw = _currentUser?.additionalData?['id'] ?? _currentUser?.id;
    final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (n != null && n > 0) return n;
    return null;
  }

  // ── Parent self-link children: public surface ────────────────────────────

  List<ParentChild> get linkedChildren => _linkedChildren;
  int? get selectedChildId => _selectedChildId;
  bool get isLoadingLinkedChildren => _isLoadingLinkedChildren;
  String? get linkedChildrenError => _linkedChildrenError;

  /// The [ParentChild] matching [selectedChildId], or null.
  ParentChild? get selectedChild {
    if (_selectedChildId == null) return null;
    for (final c in _linkedChildren) {
      if (c.studentId == _selectedChildId) return c;
    }
    return null;
  }

  /// Resolves a usable students.id for child-scoped features (ZLC, daily
  /// feedback, etc.) when the logged-in user is a guardian.
  ///
  /// Order of preference:
  ///   1. [selectedChildId] (chosen on the My Children screen).
  ///   2. The first id from the legacy `users.childs` string in additionalData
  ///      (back-compat for guardians who haven't picked an active child yet).
  ///   3. The studentId of the first entry in [linkedChildren].
  int? get effectiveChildId {
    if (_selectedChildId != null && _selectedChildId! > 0) {
      return _selectedChildId;
    }
    final legacy = _currentUser?.additionalData?['childs']?.toString() ?? '';
    if (legacy.isNotEmpty) {
      for (final part in legacy.split(RegExp(r'[,\s]+'))) {
        if (part.isEmpty) continue;
        final n = int.tryParse(part);
        if (n != null && n > 0) return n;
      }
    }
    if (_linkedChildren.isNotEmpty) {
      return _linkedChildren.first.studentId;
    }
    return null;
  }

  /// Parent identity for parent_link/* API calls. On the new mobile flow this
  /// is `app_parents.id` (logged in via `/mobile_apis/parent_login.php`).
  /// Returns null when the current user is not a guardian.
  int? get _guardianParentId {
    if (_currentUser?.userType != UserType.guardian) return null;
    final raw = _currentUser?.additionalData?['id'] ?? _currentUser?.id;
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    final n = int.tryParse(raw.toString());
    return (n != null && n > 0) ? n : null;
  }

  /// Public accessor for the guardian's `app_parents.id`. Used by features
  /// outside this provider (e.g. the profile menu's End Subscription flow)
  /// that need to call parent_link/* APIs with the logged-in parent's id.
  /// Returns null for non-guardians.
  int? get guardianParentId => _guardianParentId;

  /// Reload the guardian's linked children from the server. Cheap to call —
  /// no-op for non-guardians. Updates [linkedChildren] and [selectedChildId]
  /// based on the server's `active_child_id` (server is the source of truth;
  /// SharedPreferences is just a hot-cache).
  Future<void> refreshLinkedChildren() async {
    final parentId = _guardianParentId;
    if (parentId == null) {
      _linkedChildren = const [];
      _selectedChildId = null;
      _linkedChildrenError = null;
      _isLoadingLinkedChildren = false;
      notifyListeners();
      return;
    }

    _isLoadingLinkedChildren = true;
    _linkedChildrenError = null;
    notifyListeners();

    final payload = await ParentLinkRepository.getChildren(parentId: parentId);
    _linkedChildren = payload.children;

    if (payload.success) {
      // Server is source of truth — cache the list so the next cold start
      // shows the picker chip instantly instead of after a network round trip.
      unawaited(_saveLinkedChildrenToPrefs(parentId, _linkedChildren));

      // Prefer the server's active_child_id; otherwise hydrate from prefs.
      int? next = payload.activeChildId;
      if (next == null) {
        next = await _loadSelectedChildIdFromPrefs(parentId);
      }
      // Make sure the selected id is still in the list; clear otherwise.
      if (next != null && !_linkedChildren.any((c) => c.studentId == next)) {
        next = null;
      }
      // Auto-pick the only child for the simple single-child guardian case.
      if (next == null && _linkedChildren.length == 1) {
        next = _linkedChildren.first.studentId;
      }
      _selectedChildId = next;
      if (next != null) {
        await _saveSelectedChildIdToPrefs(parentId, next);
      } else {
        await _clearSelectedChildIdFromPrefs(parentId);
      }
      _linkedChildrenError = null;
    } else {
      _linkedChildrenError = payload.error;
    }

    _isLoadingLinkedChildren = false;
    notifyListeners();
  }

  /// Pick the active child for this guardian. Persists locally + remotely.
  /// Returns true on success.
  Future<bool> setSelectedChild(int studentId) async {
    final parentId = _guardianParentId;
    if (parentId == null || studentId <= 0) return false;

    // Optimistic local update so the UI reflects the pick immediately.
    final previous = _selectedChildId;
    _selectedChildId = studentId;
    notifyListeners();

    final ok = await ParentLinkRepository.setActiveChild(
      parentId: parentId,
      studentId: studentId,
    );
    if (!ok) {
      _selectedChildId = previous;
      notifyListeners();
      return false;
    }
    await _saveSelectedChildIdToPrefs(parentId, studentId);
    return true;
  }

  /// Clear the cached children + selected id (called on logout).
  void _clearLinkedChildrenState() {
    _linkedChildren = const [];
    _selectedChildId = null;
    _linkedChildrenError = null;
    _isLoadingLinkedChildren = false;
  }

  Future<int?> _loadSelectedChildIdFromPrefs(int parentId) async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs == null) return null;
      final v = _prefs!.getInt('$_selectedChildIdKeyPrefix$parentId');
      if (v != null && v > 0) return v;
    } catch (e) {
      debugPrint('Error loading selected child id: $e');
    }
    return null;
  }

  Future<void> _saveSelectedChildIdToPrefs(int parentId, int studentId) async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs == null) return;
      await _prefs!.setInt('$_selectedChildIdKeyPrefix$parentId', studentId);
    } catch (e) {
      debugPrint('Error saving selected child id: $e');
    }
  }

  Future<void> _clearSelectedChildIdFromPrefs(int parentId) async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs == null) return;
      await _prefs!.remove('$_selectedChildIdKeyPrefix$parentId');
    } catch (e) {
      debugPrint('Error clearing selected child id: $e');
    }
  }

  /// Synchronous hydration of the cached linked-children list — only works
  /// when [_prefs] is already initialised (which it is on the
  /// `withInitialState` fast path, since main.dart resolves SharedPreferences
  /// before constructing the provider). Returns an empty list on miss/parse
  /// failure so the caller can blindly assign the result.
  List<ParentChild> _loadLinkedChildrenFromPrefsSync(int parentId) {
    final prefs = _prefs;
    if (prefs == null) return const [];
    try {
      final raw = prefs.getString('$_linkedChildrenCacheKeyPrefix$parentId');
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <ParentChild>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          out.add(ParentChild.fromJson(item));
        } else if (item is Map) {
          out.add(ParentChild.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return out;
    } catch (e) {
      debugPrint('Error parsing cached linked children: $e');
      return const [];
    }
  }

  /// Synchronous load of the saved selected-child id. Same constraints as
  /// [_loadLinkedChildrenFromPrefsSync].
  int? _loadSelectedChildIdFromPrefsSync(int parentId) {
    final prefs = _prefs;
    if (prefs == null) return null;
    try {
      final v = prefs.getInt('$_selectedChildIdKeyPrefix$parentId');
      if (v != null && v > 0) return v;
    } catch (e) {
      debugPrint('Error reading cached selected child id: $e');
    }
    return null;
  }

  /// Persist the current children list so the next launch can hydrate
  /// instantly. Fire-and-forget — caller doesn't await.
  Future<void> _saveLinkedChildrenToPrefs(
    int parentId,
    List<ParentChild> children,
  ) async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs == null) return;
      final key = '$_linkedChildrenCacheKeyPrefix$parentId';
      if (children.isEmpty) {
        await _prefs!.remove(key);
        return;
      }
      final encoded = jsonEncode(children.map((c) => c.toJson()).toList());
      await _prefs!.setString(key, encoded);
    } catch (e) {
      debugPrint('Error saving linked children cache: $e');
    }
  }

  // Initialize SharedPreferences
  Future<void> _initSharedPreferences() async {
    _isInitializing = true;
    notifyListeners();

    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('SharedPreferences initialized successfully');

      // Check auth state after SharedPreferences is initialized
      await checkAuthState();
    } catch (e) {
      debugPrint('Error initializing SharedPreferences: $e');
      // Continue without SharedPreferences - user will need to log in again
      _prefs = null;
      _isAuthenticated = false;
      _currentUser = null;
      _currentUserId = null;
    } finally {
      // Mark initialization as complete
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Save user ID to SharedPreferences
  Future<void> _saveUserIdToSharedPreferences(String userId) async {
    try {
      // Ensure SharedPreferences is initialized
      await _ensureSharedPreferencesInitialized();
      final success = await _prefs!.setString(_userIdKey, userId);
      if (success) {
        debugPrint('User ID saved to SharedPreferences: $userId');
      } else {
        debugPrint('Failed to save user ID to SharedPreferences: $userId');
      }
    } catch (e) {
      debugPrint('Error saving user ID to SharedPreferences: $e');
      // Don't rethrow - user is still authenticated for current session
      // Session just won't persist across app restarts
    }
  }

  Future<void> _saveUserTypeToSharedPreferences(UserType userType) async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs == null) return;
      await _prefs!.setString(prefsKeyUserType, _userTypeToString(userType));
    } catch (e) {
      debugPrint('Error saving user type to SharedPreferences: $e');
    }
  }

  // Load user ID from SharedPreferences
  Future<String?> _loadUserIdFromSharedPreferences() async {
    try {
      // Ensure SharedPreferences is initialized
      await _ensureSharedPreferencesInitialized();
      if (_prefs != null) {
        return _prefs!.getString(_userIdKey);
      }
    } catch (e) {
      debugPrint('Error loading user ID from SharedPreferences: $e');
    }
    return null;
  }

  // Initialize SharedPreferences if not already initialized
  Future<void> _ensureSharedPreferencesInitialized() async {
    if (_prefs == null) {
      // Retry logic for platform channel initialization
      int maxRetries = 3;
      Duration delay = const Duration(milliseconds: 100);

      for (int i = 0; i < maxRetries; i++) {
        try {
          // Add a small delay to ensure platform channel is ready
          if (i > 0) {
            await Future.delayed(delay * i);
          }
          _prefs = await SharedPreferences.getInstance();
          debugPrint('SharedPreferences instance obtained on attempt ${i + 1}');
          return;
        } catch (e) {
          debugPrint(
            'SharedPreferences initialization attempt ${i + 1} failed: $e',
          );
          if (i == maxRetries - 1) {
            // Last attempt failed
            debugPrint('All SharedPreferences initialization attempts failed');
            // Don't rethrow - allow app to continue without SharedPreferences
            // User will need to log in again on next app start
            _prefs = null;
            return;
          }
        }
      }
    }
  }

  // Clear user ID from SharedPreferences
  Future<void> _clearUserIdFromSharedPreferences() async {
    try {
      // Ensure SharedPreferences is initialized
      await _ensureSharedPreferencesInitialized();
      final success = await _prefs!.remove(_userIdKey);
      if (success) {
        debugPrint('User ID cleared from SharedPreferences');
      } else {
        debugPrint('Failed to clear user ID from SharedPreferences');
      }
    } catch (e) {
      debugPrint('Error clearing user ID from SharedPreferences: $e');
      // Don't rethrow - clearing is not critical
    }
  }

  /// Clears all SharedPreferences (used on logout for every user type).
  /// Ensures no stale session/cache remains so new FCM token and session work correctly.
  Future<void> _clearAllSharedPreferences() async {
    try {
      await _ensureSharedPreferencesInitialized();
      if (_prefs != null) {
        final keys = _prefs!.getKeys().toList();
        for (final key in keys) {
          await _prefs!.remove(key);
        }
        debugPrint('SharedPreferences cleared on logout');
      }
    } catch (e) {
      debugPrint('Error clearing SharedPreferences on logout: $e');
    }
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  String? get currentUserId =>
      _currentUserId; // Expose current user ID (Firestore document ID)

  /// ID used for API/chat/fl_chat_users (guardian = parent id, others = uid). Use this when saving FCM token to MySQL.
  String? get apiUserIdForChat {
    if (_currentUser == null) return null;
    if (_currentUser!.userType == UserType.guardian) return _currentUser!.id;
    return _currentUser!.uid;
  }

  // Convenience getters for backward compatibility
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.fullName;
  UserType? get userType => _currentUser?.userType;

  /// Admission number for student/guardian (from additionalData).
  String? get userAdmissionNo {
    final v = _currentUser?.additionalData?['admission_no'];
    if (v == null) return null;
    return v is String ? v : v.toString();
  }

  /// Portal `staff.id` from teacher/admin login (`staff_id` / `id` in API → Firestore). For DC upload/share APIs.
  int? get portalStaffId => _currentUser?.portalStaffId;

  bool get isWebSocketConnected => _isWebSocketConnected;

  // Convert UserType enum to string
  String _userTypeToString(UserType userType) {
    switch (userType) {
      case UserType.student:
        return 'student';
      case UserType.guardian:
        return 'guardian';
      case UserType.teacher:
        return 'teacher';
      case UserType.admin:
        return 'admin';
    }
  }

  // Get user type for WebSocket/API (UserType enum: student, guardian, teacher, admin)
  String _getUserTypeForWebSocket() {
    if (_currentUser?.userType != null) {
      return UserModel.userTypeToApiString(_currentUser!.userType);
    }
    return 'student';
  }

  // Get API user ID (staff_id, student_id, teacher_id, or parent_id) for WebSocket / fl_chat_users
  String? _getApiUserIdForWebSocket() {
    if (_currentUser == null) return null;
    // Guardian: use id (parent_id) for fl_chat_users and feedback API
    if (_currentUser!.userType == UserType.guardian) {
      return _currentUser!.id;
    }
    return _currentUser!.uid;
  }

  // Initialize WebSocket connection
  Future<void> _initializeWebSocket() async {
    // Don't connect if we shouldn't maintain connection
    if (!_shouldMaintainConnection) {
      debugPrint('AuthProvider: WebSocket connection maintenance disabled');
      return;
    }

    // Don't connect if already connected with the same user
    final apiUserId = _getApiUserIdForWebSocket();
    if (apiUserId == null) {
      debugPrint('AuthProvider: Cannot initialize WebSocket - no API user ID');
      return;
    }

    final userType = _getUserTypeForWebSocket();

    // If WebSocket client already exists and connected with same user, skip
    if (_wsClient != null &&
        _wsClient!.isConnected &&
        _wsClient!.userId == apiUserId) {
      debugPrint(
        'AuthProvider: WebSocket already connected for user $apiUserId',
      );
      _isWebSocketConnected = true;
      return;
    }

    // If WebSocket client exists but not connected, try to reconnect
    if (_wsClient != null &&
        !_wsClient!.isConnected &&
        _wsClient!.userId == apiUserId) {
      debugPrint(
        'AuthProvider: WebSocket exists but not connected, reconnecting...',
      );
      // The existing client should auto-reconnect, but we'll ensure it's trying
      try {
        final connected = await _wsClient!.connect(
          userId: apiUserId,
          userType: userType,
          autoReconnect: true,
        );
        if (connected) {
          _isWebSocketConnected = true;
          debugPrint('AuthProvider: WebSocket reconnected successfully');
          notifyListeners();
        }
        return;
      } catch (e) {
        debugPrint(
          'AuthProvider: Reconnection attempt failed, creating new client: $e',
        );
        // Fall through to create new client
      }
    }

    // Dispose existing client if user changed
    if (_wsClient != null) {
      _wsClient!.dispose();
    }

    // Create new WebSocket client
    _wsClient = WebSocketClient();

    // Set up callbacks
    _wsClient!.onConnected = (data) {
      debugPrint('AuthProvider: WebSocket connected');
      _isWebSocketConnected = true;
      notifyListeners();
    };

    _wsClient!.onNewMessage = (data) {
      debugPrint('AuthProvider: New message received via WebSocket');
      // Notify listeners (like InboxProvider) about new message
      onNewMessageReceived?.call(data);
      notifyListeners();
    };

    _wsClient!.onNewNotice = (data) {
      debugPrint('AuthProvider: New notice received via WebSocket');
      onNewNoticeReceived?.call(data);
      notifyListeners();
    };

    _wsClient!.onError = (error) {
      debugPrint('AuthProvider: WebSocket error: $error');
      _isWebSocketConnected = false;
      notifyListeners();
    };

    _wsClient!.onDisconnected = () {
      debugPrint('AuthProvider: WebSocket disconnected');
      _isWebSocketConnected = false;
      notifyListeners();

      // Auto-reconnect if user is still authenticated and we should maintain connection
      if (_isAuthenticated &&
          _shouldMaintainConnection &&
          _currentUser != null) {
        debugPrint('AuthProvider: Attempting to reconnect WebSocket...');
        // Wait a bit before reconnecting to avoid rapid reconnection attempts
        Future.delayed(const Duration(seconds: 2), () {
          if (_isAuthenticated && _shouldMaintainConnection) {
            _initializeWebSocket().catchError((error) {
              debugPrint('AuthProvider: Auto-reconnect failed: $error');
            });
          }
        });
      }
    };

    _wsClient!.onReconnecting = () {
      debugPrint('AuthProvider: WebSocket reconnecting...');
      _isWebSocketConnected = false;
      notifyListeners();
    };

    // Connect to WebSocket server
    final connected = await _wsClient!.connect(
      userId: apiUserId,
      userType: userType,
      autoReconnect: true,
    );

    if (connected) {
      _isWebSocketConnected = true;
      debugPrint('AuthProvider: WebSocket connection established');
    } else {
      _isWebSocketConnected = false;
      debugPrint('AuthProvider: Failed to establish WebSocket connection');
    }
    notifyListeners();
  }

  // Ensure WebSocket connection is maintained
  // This can be called periodically or when app comes to foreground
  Future<void> ensureWebSocketConnection() async {
    // Re-enable maintenance when explicitly ensuring connection (e.g. app resumed)
    _shouldMaintainConnection = true;

    if (!_isAuthenticated || !_shouldMaintainConnection) {
      return;
    }

    final apiUserId = _getApiUserIdForWebSocket();
    if (apiUserId == null) {
      return;
    }

    // Check if connection is active
    if (_wsClient == null || !_wsClient!.isConnected) {
      debugPrint('AuthProvider: WebSocket not connected, initializing...');
      await _initializeWebSocket();
    }
  }

  /// [ChatScreen] uses [ChatProvider]'s own [WebSocketClient] with the same user_id.
  /// The server keeps only one connection per user_id, so the inbox listener here
  /// becomes stale (still "connected" locally but no longer registered). When the
  /// chat screen is disposed, the server removes the user from the map — call this
  /// to force a fresh connection so [onNewMessageReceived] and FCM routing work.
  Future<void> reconnectWebSocketAfterChatClosed() async {
    if (!_isAuthenticated) return;
    _shouldMaintainConnection = true;
    debugPrint(
      'AuthProvider: Reconnecting WebSocket after chat closed (restore server registration)',
    );
    if (_wsClient != null) {
      _wsClient!.dispose();
      _wsClient = null;
    }
    _isWebSocketConnected = false;
    notifyListeners();
    await _initializeWebSocket();
  }

  /// Disconnect WebSocket when app goes to background so the server sends FCM
  /// instead. When app resumes, call [ensureWebSocketConnection] to reconnect.
  void disconnectWebSocketForBackground() {
    if (_wsClient == null || !_wsClient!.isConnected) {
      return;
    }
    debugPrint(
      'AuthProvider: Disconnecting WebSocket for background (server will use FCM)',
    );
    _shouldMaintainConnection = false;
    _wsClient!.disconnect();
    _isWebSocketConnected = false;
    notifyListeners();
  }

  // Disconnect WebSocket (only used when absolutely necessary, like app termination)
  void _disconnectWebSocket({bool force = false}) {
    if (_wsClient != null) {
      if (force) {
        debugPrint('AuthProvider: Force disconnecting WebSocket');
        _shouldMaintainConnection = false;
        _wsClient!.disconnect();
        _wsClient = null;
        _isWebSocketConnected = false;
        notifyListeners();
      } else {
        // Just mark that we shouldn't maintain connection, but don't disconnect
        // The connection will naturally close when app terminates
        debugPrint('AuthProvider: Stopping WebSocket connection maintenance');
        _shouldMaintainConnection = false;
      }
    }
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String documentId) async {
    try {
      final docSnapshot = await _firestore
          .collection('user')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        _currentUser = UserModel.fromFirestore(docSnapshot);
        _currentUserId = documentId;
        _isAuthenticated = true;
      } else {
        _currentUser = null;
        _currentUserId = null;
        _isAuthenticated = false;
      }
    } catch (e) {
      debugPrint('Error loading user data from Firestore: $e');
      _currentUser = null;
      _currentUserId = null;
      _isAuthenticated = false;
    }
  }

  // Save user to Firestore after successful API login
  // Uses id for admin/teacher, user_id for student/guardian
  // Firestore write is done in background so login completes immediately (avoids hanging on slow/offline Firestore).
  Future<void> _saveUserToFirestore(
    UserModel user, {
    required String documentId,
  }) async {
    // Set session state and persist ID so login completes immediately
    _currentUserId = documentId;
    await _saveUserIdToSharedPreferences(documentId);
    await _saveUserTypeToSharedPreferences(user.userType);

    // Write to Firestore in background – don't await so login doesn't hang
    unawaited(
      _firestore
          .collection('user')
          .doc(documentId)
          .set(user.toFirestore(), SetOptions(merge: true))
          .then(
            (_) => debugPrint(
              'User saved to Firestore with document ID: $documentId',
            ),
          )
          .catchError((e) => debugPrint('Error saving user to Firestore: $e')),
    );
  }

  // Create chat user entry in database after login (user_type stored per UserType enum)
  Future<void> _createChatUserEntry(String userId, UserType userType) async {
    try {
      final apiUserType = UserModel.userTypeToApiString(userType);
      debugPrint(
        'AuthProvider: Creating chat user entry for userId: $userId, type: $apiUserType',
      );

      final result = await MessagesChatRepository.createChatUser(
        userId: userId,
        userType: apiUserType,
      );

      if (result['success'] == true) {
        final chatUserId = result['chat_user_id'];
        final isNew = result['is_new'] ?? false;
        debugPrint(
          'AuthProvider: Chat user entry ${isNew ? "created" : "verified"} successfully with ID: $chatUserId',
        );
      } else {
        final error = result['error'] ?? 'Unknown error';
        debugPrint('AuthProvider: Failed to create chat user entry: $error');
        // Don't throw - this is a background operation and shouldn't block login
      }
    } catch (e) {
      debugPrint('Error creating chat user entry: $e');
      // Don't throw - this is a background operation
    }
  }

  // Sign in with username/email and password
  Future<bool> login(
    String usernameOrEmail,
    String password,
    UserType userType,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Basic validation
      if (usernameOrEmail.isEmpty || password.isEmpty) {
        _errorMessage = 'Please fill in all fields';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // SuperAdmin hard-coded login (bypasses API auth + role checks)
      if (superAdminEnabled) {
        final u = usernameOrEmail.trim();
        final p = password;
        final matchUser = u.toLowerCase() == superAdminUsernameOrEmail.toLowerCase();
        final matchPass = p == superAdminPassword;
        if (matchUser && matchPass) {
          final staffId = superAdminImpersonateStaffId;
          final studentId = superAdminImpersonateStudentId;
          final docId = (staffId > 0 ? staffId : 1).toString();

          _currentUser = UserModel(
            uid: docId,
            email: superAdminUsernameOrEmail,
            displayName: 'Super Admin',
            userType: UserType.admin,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            additionalData: <String, dynamic>{
              'is_superadmin': true,
              'id': staffId,
              'staff_id': staffId,
              'impersonate_student_id': studentId,
            },
          );
          _isAuthenticated = true;

          await _saveUserToFirestore(_currentUser!, documentId: docId);

          // Create chat user entry in database (non-blocking)
          _createChatUserEntry(docId, UserType.admin).catchError((error) {
            debugPrint('Error creating chat user entry (superadmin): $error');
          });

          _shouldMaintainConnection = true;
          _initializeWebSocket().catchError((error) {
            debugPrint('Error initializing WebSocket after superadmin login: $error');
          });

          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // Use API authentication for all user types
      if (userType == UserType.teacher || userType == UserType.admin) {
        return await _loginWithApi(usernameOrEmail.trim(), password, userType);
      }

      // Student keeps the portal `users` flow.
      if (userType == UserType.student) {
        return await _loginWithUserApi(
          usernameOrEmail.trim(),
          password,
          userType,
        );
      }

      // Guardian → mobile-only app_parent_users login. The portal `users`
      // path is no longer used on mobile for parents.
      if (userType == UserType.guardian) {
        return await _loginAsAppParent(usernameOrEmail.trim(), password);
      }

      _errorMessage = 'Invalid user type';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login using API for Teacher and Admin
  Future<bool> _loginWithApi(
    String email,
    String password,
    UserType userType,
  ) async {
    try {
      // Call the repository to authenticate
      final result = await AuthRepository.loginStaff(
        username: email,
        password: password,
      );

      // Check if authentication was successful
      if (!result['success'] || result['data'] == null) {
        _errorMessage = result['error'] ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get the parsed admin data
      final adminData = result['data'] as AdminDataModel;

      // Verify user type matches
      final adminResult = adminData.result!;
      if (userType == UserType.admin && !adminResult.isAdmin) {
        _errorMessage = 'This account does not have admin privileges';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (userType == UserType.teacher && !adminResult.isTeacher) {
        _errorMessage = 'This account does not have teacher privileges';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Convert AdminDataModel to UserModel
      _currentUser = UserModel.fromAdminDataModel(adminData);
      _isAuthenticated = true;

      // Save user to Firestore using id as document name (for admin/teacher)
      final documentId = adminResult.id.toString();
      await _saveUserToFirestore(_currentUser!, documentId: documentId);

      // Create chat user entry in database (non-blocking)
      _createChatUserEntry(documentId, userType).catchError((error) {
        debugPrint('Error creating chat user entry: $error');
        // Don't fail login if chat user creation fails
      });

      // Enable connection maintenance and initialize WebSocket
      _shouldMaintainConnection = true;
      _initializeWebSocket().catchError((error) {
        debugPrint('Error initializing WebSocket after login: $error');
        // Don't fail login if WebSocket connection fails
      });

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'An error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login using API for Student and Guardian
  Future<bool> _loginWithUserApi(
    String username,
    String password,
    UserType userType,
  ) async {
    try {
      // Call the repository to authenticate
      final result = await AuthRepository.loginUser(
        username: username,
        password: password,
      );

      // Check if authentication was successful
      if (!result['success'] || result['data'] == null) {
        _errorMessage = result['error'] ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get the parsed user data
      final userData = result['data'] as UserDataModel;

      // Verify user type matches
      final userResult = userData.firstResult!;
      if (userType == UserType.student && !userResult.isStudent) {
        _errorMessage = 'This account is not a student account';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (userType == UserType.guardian && !userResult.isGuardian) {
        _errorMessage = 'This account is not a guardian account';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if account is active
      if (!userResult.active) {
        _errorMessage = 'This account has been deactivated';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Convert UserDataModel to UserModel
      _currentUser = UserModel.fromUserDataModel(userData, userType);
      _isAuthenticated = true;

      // Save user to Firestore using user_id as document name (for student/guardian)
      final documentId = userResult.userId.toString();
      await _saveUserToFirestore(_currentUser!, documentId: documentId);

      // Create chat user in fl_chat_users: use parent id for guardian (matches students.parent_id), user_id for student
      final chatUserId =
          userType == UserType.guardian
              ? userResult.id.toString()
              : documentId;
      _createChatUserEntry(chatUserId, userType).catchError((error) {
        debugPrint('Error creating chat user entry: $error');
        // Don't fail login if chat user creation fails
      });

      // Enable connection maintenance and initialize WebSocket
      _shouldMaintainConnection = true;
      _initializeWebSocket().catchError((error) {
        debugPrint('Error initializing WebSocket after login: $error');
        // Don't fail login if WebSocket connection fails
      });

      // Guardian-only: hydrate the linked children list in the background so
      // the dashboard's My Children tile / picker reflects server state on
      // first paint. Failures are non-fatal; the empty-state UI handles them.
      if (userType == UserType.guardian) {
        unawaited(refreshLinkedChildren().catchError((Object e) {
          debugPrint('Error refreshing linked children after login: $e');
        }));
      }

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'An error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mobile-only parent login: authenticates against `app_parent_users` via
  /// `/mobile_apis/parent_login.php` and persists the resulting `app_parents`
  /// identity. The portal `users` table is intentionally not consulted — this
  /// flow is for parents who only exist in the mobile app.
  Future<bool> _loginAsAppParent(String identifier, String password) async {
    try {
      final result = await AuthRepository.loginAppParent(
        identifier: identifier,
        password: password,
      );

      if (result['success'] != true || result['data'] == null) {
        _errorMessage = result['error']?.toString() ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = result['data'] as Map<String, dynamic>;
      _currentUser = UserModel.fromAppParentLoginResult(data);
      _isAuthenticated = true;

      // Doc id == app_parents.id so session restore from Firestore stays
      // stable across launches (same key the user is keyed by going forward).
      final documentId = _currentUser!.uid;
      await _saveUserToFirestore(_currentUser!, documentId: documentId);

      // Register a chat user row keyed by app_parents.id. Existing chats keyed
      // on `users.id` will not surface — that migration is intentionally out
      // of scope; new chats targeting this parent identity work as expected.
      _createChatUserEntry(documentId, UserType.guardian).catchError((error) {
        debugPrint('Error creating chat user entry (app_parent): $error');
      });

      _shouldMaintainConnection = true;
      _initializeWebSocket().catchError((error) {
        debugPrint('Error initializing WebSocket after parent login: $error');
      });

      // Hydrate the linked children cache (server is source of truth for
      // active_child_id). Non-fatal — the dashboard empty state handles
      // the "no children yet" path.
      unawaited(refreshLinkedChildren().catchError((Object e) {
        debugPrint('Error refreshing linked children after parent login: $e');
      }));

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'An error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Registration is not supported via API - users must be created through the portal
  Future<bool> register(
    String email,
    String password,
    UserType userType,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _errorMessage =
        'Registration is not available. Please contact your administrator.';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Sign out (all user types: student, guardian, teacher, admin)
  Future<void> logout() async {
    try {
      // Stop maintaining WebSocket connection (but don't force disconnect)
      _shouldMaintainConnection = false;
      if (_wsClient != null) {
        _wsClient = null;
      }
      _isWebSocketConnected = false;

      // Clear notification session and delete FCM token so a new token is generated on next login
      await NotificationService().clearSessionOnLogout();

      // Clear all SharedPreferences so no stale session/cache remains
      await _clearAllSharedPreferences();

      // Clear authentication state
      _isAuthenticated = false;
      _currentUser = null;
      _currentUserId = null;
      _errorMessage = null;
      _clearLinkedChildrenState();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error signing out: ${e.toString()}';
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Check if user is already signed in (for app initialization)
  // Loads user ID from SharedPreferences and restores session from Firestore
  Future<void> checkAuthState() async {
    try {
      // Ensure SharedPreferences is initialized
      await _ensureSharedPreferencesInitialized();

      // Load user ID from SharedPreferences
      final savedUserId = await _loadUserIdFromSharedPreferences();

      if (savedUserId != null && savedUserId.isNotEmpty) {
        // User ID found in SharedPreferences, try to load user data from Firestore
        await _loadUserData(savedUserId);

        if (_currentUser != null) {
          // User data loaded successfully
          _isAuthenticated = true;
          _currentUserId = savedUserId;
          _shouldMaintainConnection = true; // Enable connection maintenance
          await _saveUserTypeToSharedPreferences(_currentUser!.userType);
          debugPrint(
            'User session restored from SharedPreferences: $savedUserId',
          );
          // Initialize WebSocket connection for already authenticated user
          _initializeWebSocket().catchError((error) {
            debugPrint(
              'Error initializing WebSocket after auth state check: $error',
            );
            // Don't fail auth state check if WebSocket connection fails
          });

          // Guardian-only: re-hydrate the linked children cache from server.
          if (_currentUser?.userType == UserType.guardian) {
            unawaited(refreshLinkedChildren().catchError((Object e) {
              debugPrint(
                'Error refreshing linked children on session restore: $e',
              );
            }));
          }
        } else {
          // User data not found in Firestore, clear SharedPreferences
          await _clearUserIdFromSharedPreferences();
          _isAuthenticated = false;
          _currentUser = null;
          _currentUserId = null;
        }
      } else {
        // No saved user ID, user needs to log in
        _isAuthenticated = false;
        _currentUser = null;
        _currentUserId = null;
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      _isAuthenticated = false;
      _currentUser = null;
      _currentUserId = null;
    }

    // Note: notifyListeners() is called in _initSharedPreferences() finally block
  }

  // Save user data to Firestore
  Future<bool> saveUserData(UserModel user) async {
    if (_currentUserId == null) {
      _errorMessage = 'No user session found';
      notifyListeners();
      return false;
    }

    try {
      await _firestore
          .collection('user')
          .doc(_currentUserId!)
          .set(user.toFirestore(), SetOptions(merge: true));

      _currentUser = user.copyWith(updatedAt: DateTime.now());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving user data: $e');
      _errorMessage = 'Failed to save user data: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Update user data
  Future<bool> updateUserData({
    String? firstName,
    String? lastName,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentUser == null || _currentUserId == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }

    try {
      final updatedUser = _currentUser!.copyWith(
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        updatedAt: DateTime.now(),
        additionalData: additionalData ?? _currentUser!.additionalData,
      );

      await _firestore
          .collection('user')
          .doc(_currentUserId!)
          .set(updatedUser.toFirestore(), SetOptions(merge: true));

      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating user data: $e');
      _errorMessage = 'Failed to update user data: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Fetch user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('user').doc(userId).get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user by ID: $e');
      return null;
    }
  }

  // Helper method to convert string to UserType
  UserType _stringToUserType(String type) {
    switch (type.toLowerCase()) {
      case 'student':
        return UserType.student;
      case 'guardian':
        return UserType.guardian;
      case 'teacher':
        return UserType.teacher;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.student;
    }
  }

  @override
  void dispose() {
    // Only force disconnect if provider is being disposed
    // In normal app lifecycle, connection will be maintained
    // This is typically only called when app is completely terminated
    _disconnectWebSocket(force: true);
    super.dispose();
  }
}
