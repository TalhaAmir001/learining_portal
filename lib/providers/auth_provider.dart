import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/network/data_models/auth/admin_data_model.dart';
import 'package:learining_portal/network/data_models/auth/user_data_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:learining_portal/network/domain/auth_repository.dart';

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
  }

  bool get isInitializing => _isInitializing;

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

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  String? get currentUserId =>
      _currentUserId; // Expose current user ID (Firestore document ID)

  // Convenience getters for backward compatibility
  String? get userEmail => _currentUser?.email;
  UserType? get userType => _currentUser?.userType;

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
  Future<void> _saveUserToFirestore(
    UserModel user, {
    required String documentId,
  }) async {
    try {
      await _firestore
          .collection('user')
          .doc(documentId)
          .set(user.toFirestore(), SetOptions(merge: true));

      _currentUserId = documentId;

      // Save user ID to SharedPreferences for persistent authentication
      await _saveUserIdToSharedPreferences(documentId);

      debugPrint('User saved to Firestore with document ID: $documentId');
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
      // Don't throw error, just log it - user is still authenticated via API
    }
  }

  // Create chat user entry in database after login
  Future<void> _createChatUserEntry(String userId, UserType userType) async {
    try {
      // Map UserType to API user_type
      String apiUserType;
      if (userType == UserType.teacher || userType == UserType.admin) {
        apiUserType = 'staff';
      } else {
        apiUserType = 'student';
      }

      debugPrint(
        'AuthProvider: Creating chat user entry for userId: $userId, type: $apiUserType',
      );

      // Create chat user entry via HTTP API
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

      // Use API authentication for all user types
      if (userType == UserType.teacher || userType == UserType.admin) {
        return await _loginWithApi(usernameOrEmail.trim(), password, userType);
      }

      // Use API authentication for Student and Guardian
      if (userType == UserType.student || userType == UserType.guardian) {
        return await _loginWithUserApi(
          usernameOrEmail.trim(),
          password,
          userType,
        );
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

      // Create chat user entry in database (non-blocking)
      _createChatUserEntry(documentId, userType).catchError((error) {
        debugPrint('Error creating chat user entry: $error');
        // Don't fail login if chat user creation fails
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

  // Sign out
  Future<void> logout() async {
    try {
      // Clear user ID from SharedPreferences
      await _clearUserIdFromSharedPreferences();

      // Clear authentication state
      _isAuthenticated = false;
      _currentUser = null;
      _currentUserId = null;
      _errorMessage = null;
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
          debugPrint(
            'User session restored from SharedPreferences: $savedUserId',
          );
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
}
