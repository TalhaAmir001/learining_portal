import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/auth_provider.dart';
import 'providers/messages/inbox_provider.dart';
import 'providers/messages/members_provider.dart';
import 'providers/messages/notification_provider.dart';
import 'providers/notifications/notice_board_provider.dart';
import 'models/user_model.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';
import 'services/notification_service.dart';

// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization warning: $e');
    }
  }

  // Small delay to ensure platform channels are fully initialized
  // This helps prevent "Unable to establish connection" errors
  await Future.delayed(const Duration(milliseconds: 50));

  // CRITICAL: Register background message handler BEFORE runApp()
  // This must be done at the top level, before the app starts
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (kDebugMode) {
    debugPrint('Background message handler registered');
  }

  // Check if user is logged in before starting the app
  final initialAuthState = await _checkInitialAuthState();

  runApp(MyApp(initialAuthState: initialAuthState));
}

// Check authentication state from SharedPreferences before app starts
Future<InitialAuthState> _checkInitialAuthState() async {
  // Helper function to get SharedPreferences with retry logic
  Future<SharedPreferences?> _getSharedPreferencesWithRetry({
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        // Add a small delay to ensure platform channel is ready
        if (i > 0) {
          await Future.delayed(delay * i);
        }
        final prefs = await SharedPreferences.getInstance();
        if (kDebugMode) {
          debugPrint(
            'SharedPreferences obtained successfully on attempt ${i + 1}',
          );
        }
        return prefs;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SharedPreferences attempt ${i + 1} failed: $e');
        }
        if (i == maxRetries - 1) {
          // Last attempt failed
          if (kDebugMode) {
            debugPrint('All SharedPreferences attempts failed');
          }
          return null;
        }
      }
    }
    return null;
  }

  try {
    final prefs = await _getSharedPreferencesWithRetry();
    if (prefs == null) {
      // Could not get SharedPreferences, return unauthenticated state
      if (kDebugMode) {
        debugPrint(
          'Could not initialize SharedPreferences, starting unauthenticated',
        );
      }
      return InitialAuthState(isAuthenticated: false, prefs: null);
    }

    const userIdKey = 'current_user_id';
    final savedUserId = prefs.getString(userIdKey);

    if (savedUserId != null && savedUserId.isNotEmpty) {
      // Try to load user data from Firestore
      try {
        final firestore = FirebaseFirestore.instance;
        final docSnapshot = await firestore
            .collection('user')
            .doc(savedUserId)
            .get();

        if (docSnapshot.exists) {
          final user = UserModel.fromFirestore(docSnapshot);
          if (kDebugMode) {
            debugPrint('User session found: ${user.email}');
          }
          return InitialAuthState(
            isAuthenticated: true,
            currentUser: user,
            currentUserId: savedUserId,
            prefs: prefs,
          );
        } else {
          // User data not found in Firestore, clear SharedPreferences
          try {
            await prefs.remove(userIdKey);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error clearing invalid session: $e');
            }
          }
          if (kDebugMode) {
            debugPrint(
              'User data not found in Firestore, clearing saved session',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error loading user data: $e');
        }
        // Clear invalid session
        try {
          await prefs.remove(userIdKey);
        } catch (clearError) {
          if (kDebugMode) {
            debugPrint('Error clearing invalid session: $clearError');
          }
        }
      }
    }

    // No valid session found, but we have prefs
    return InitialAuthState(isAuthenticated: false, prefs: prefs);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error checking initial auth state: $e');
    }
    // Return unauthenticated state without prefs
    return InitialAuthState(isAuthenticated: false, prefs: null);
  }
}

// Helper class to pass initial auth state to MyApp
class InitialAuthState {
  final bool isAuthenticated;
  final UserModel? currentUser;
  final String? currentUserId;
  final SharedPreferences? prefs;

  InitialAuthState({
    required this.isAuthenticated,
    this.currentUser,
    this.currentUserId,
    this.prefs,
  });
}

class MyApp extends StatelessWidget {
  final InitialAuthState initialAuthState;

  const MyApp({super.key, required this.initialAuthState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider.withInitialState(
            isAuthenticated: initialAuthState.isAuthenticated,
            currentUser: initialAuthState.currentUser,
            currentUserId: initialAuthState.currentUserId,
            prefs: initialAuthState.prefs,
          ),
        ),
        ChangeNotifierProvider(create: (_) => InboxProvider()),
        ChangeNotifierProvider(create: (_) => MembersProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NoticeBoardProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Learning Portal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize notifications and WebSocket message listener after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      final inboxProvider = Provider.of<InboxProvider>(context, listen: false);

      notificationProvider.initialize(authProvider);

      // Set up WebSocket message listener to refresh inbox when new messages arrive
      authProvider.onNewMessageReceived = (messageData) {
        debugPrint('Main: New message received, refreshing inbox');
        // Refresh inbox to show new messages
        inboxProvider.refreshChats();
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - ensure WebSocket is connected
      debugPrint('Main: App resumed, ensuring WebSocket connection');
      if (authProvider.isAuthenticated) {
        authProvider.ensureWebSocketConnection().catchError((error) {
          debugPrint('Main: Error ensuring WebSocket connection: $error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        // Update notification provider when auth state changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notificationProvider.onAuthStateChanged(authProvider);
        });

        // If user is already logged in, go directly to Dashboard
        if (authProvider.isAuthenticated) {
          return const DashboardScreen();
        } else {
          // If not authenticated, show auth screen
          return const AuthScreen();
        }
      },
    );
  }
}
