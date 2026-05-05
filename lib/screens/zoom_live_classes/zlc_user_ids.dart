import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';

/// Resolves Portal `students.id` for ZLC list/join/feedback APIs.
int? zlcPortalStudentId(UserModel? user) {
  if (user == null) return null;
  if (user.userType == UserType.student) {
    return int.tryParse(user.id ?? '');
  }
  if (user.userType == UserType.guardian) {
    final raw = user.additionalData?['childs']?.toString() ?? '';
    for (final part in raw.split(RegExp(r'[,\s]+'))) {
      if (part.isEmpty) continue;
      final n = int.tryParse(part);
      if (n != null && n > 0) return n;
    }
  }
  return null;
}
