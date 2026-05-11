import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared Firebase Firestore instance for the entire app
final FirebaseFirestore firestore = FirebaseFirestore.instance;

/// Shared Firebase Auth instance for the entire app
final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

/// Virtual Support user ID (staff_id = 0 in backend). Students and teachers chat only with Support; any admin can reply.
const String supportUserId = '0';

/// [SharedPreferences] key for the logged-in app role (`student` | `guardian` | `teacher` | `admin`).
/// Used by background FCM so chat notification titles match in-app rules (e.g. "Support" for non-admins).
const String prefsKeyUserType = 'current_user_type';

/// Opened from the dashboard profile menu (“Request delete account”). Set to your live form or policy URL.
const String accountDeletionRequestUrl =
    'https://portal.gcsewithrosi.co.uk/request-account-deletion';

/// Hard-coded SuperAdmin login (bypasses role gating in-app).
///
/// Keep this enabled only for internal/testing builds.
const bool superAdminEnabled = true;

/// Username/email used on the login screen.
const String superAdminUsernameOrEmail = 'superadmin';

/// Password used on the login screen.
const String superAdminPassword = 'password';

/// SuperAdmin "impersonation" IDs for calling role-specific APIs.
///
/// Some app features require a student_id or staff_id for backend endpoints.
/// Set these to a real existing student/staff row id from your DB.
const int superAdminImpersonateStudentId = 1;
const int superAdminImpersonateStaffId = 1;
