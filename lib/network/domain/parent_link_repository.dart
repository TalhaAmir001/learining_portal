import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for the "Parent Self-Link Children" mobile feature.
///
/// All endpoints take a parent identity. On mobile, parents now log in via
/// `/mobile_apis/parent_login.php` against the `app_parent_users` table, so
/// the id we send is `app_parents.id` and `caller_user_type` is `app_parent`
/// (server resolves it directly, no bridge through `users`).
///
/// This repository never throws — every method returns a typed payload so the
/// UI can branch cleanly on success / outcome.
class ParentLinkRepository {
  static const String _userType = 'app_parent';

  /// GET children currently linked to this guardian + the saved active child.
  static Future<ParentChildrenPayload> getChildren({
    required int parentId,
  }) async {
    if (parentId <= 0) {
      return const ParentChildrenPayload(
        success: false,
        error: 'Missing or invalid parent_id.',
      );
    }
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_parent_children.php',
        body: {
          'caller_user_type': _userType,
          'caller_user_id': parentId,
        },
      );
      return ParentChildrenPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ParentLinkRepository.getChildren: ${e.message}');
      return ParentChildrenPayload(success: false, error: e.message);
    }
  }

  /// Submit a one-time `mobile_app_code` (6 alphanumeric chars, school-issued).
  /// Server will either link instantly, report the code is already linked to
  /// this caller, or reject the claim (used / unknown code).
  static Future<LinkChildResult> linkChildRequest({
    required int parentId,
    required String mobileAppCode,
  }) async {
    if (parentId <= 0) {
      return LinkChildResult.error('Missing or invalid parent_id.');
    }
    final code = mobileAppCode.trim().toUpperCase();
    if (code.isEmpty) {
      return LinkChildResult.error('Please enter the 6-character code.');
    }
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/link_child_request.php',
        body: {
          'caller_user_type': _userType,
          'caller_user_id': parentId,
          'mobile_app_code': code,
        },
      );
      return LinkChildResult.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ParentLinkRepository.linkChildRequest: ${e.message}');
      return LinkChildResult.error(e.message);
    }
  }

  /// Staff-side lookup: given a parent identifier (either `app_parents.id`
  /// from the new flow or a legacy `users.id`), returns that parent's
  /// currently active child — or `null` if there is none or the id doesn't
  /// resolve to a guardian. Used by the chat screen so a teacher/admin can
  /// see which child a Support thread is about.
  ///
  /// Returns `null` on any failure (network, parse, no active child); the UI
  /// should silently hide the bar in that case rather than show an error.
  static Future<ParentChild?> getActiveChildForParent({
    required int parentId,
  }) async {
    if (parentId <= 0) return null;
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_app_parent_summary.php',
        body: {'parent_id': parentId},
      );
      if (r['success'] != true) return null;
      final raw = r['active_child'];
      if (raw is Map<String, dynamic>) {
        return ParentChild.fromJson(raw);
      }
      if (raw is Map) {
        return ParentChild.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('ParentLinkRepository.getActiveChildForParent: ${e.message}');
      return null;
    }
  }

  /// Pick the active child for this guardian. Server validates that the
  /// student is currently linked to the caller.
  static Future<bool> setActiveChild({
    required int parentId,
    required int studentId,
  }) async {
    if (parentId <= 0 || studentId <= 0) return false;
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/set_active_child.php',
        body: {
          'caller_user_type': _userType,
          'caller_user_id': parentId,
          'student_id': studentId,
        },
      );
      return r['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ParentLinkRepository.setActiveChild: ${e.message}');
      return false;
    }
  }
}
