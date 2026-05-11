import 'package:learining_portal/providers/auth_provider.dart';

/// Resolves Portal `students.id` for ZLC list/join/feedback APIs.
///
/// • Student → parses `users.uid` (which is set to the student row id).
/// • Guardian → returns [AuthProvider.effectiveChildId], which prefers the
///   guardian's selected child (set on My Children screen) over the legacy
///   `users.childs` first-id parsing.
int? zlcPortalStudentId(AuthProvider auth) {
  final user = auth.currentUser;
  if (user == null) return null;
  if (user.userType == UserType.student) {
    return int.tryParse(user.id ?? '');
  }
  if (user.userType == UserType.guardian) {
    return auth.effectiveChildId;
  }
  return null;
}
