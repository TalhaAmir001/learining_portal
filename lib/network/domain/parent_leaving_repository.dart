import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of a leaving-notice submission. Mirrors the JSON returned by
/// `/mobile_apis/submit_leaving_notice.php`.
@immutable
class LeavingNoticeResult {
  final bool success;
  final String? error;
  final DateTime? leavingDate;
  final DateTime? minLeavingDate;

  /// Server-confirmed active child snapshot (`null` when the submission did
  /// not include one, or when the id wasn't linked to this parent and was
  /// silently dropped). Mostly useful for tests / debugging — the UI
  /// already shows the snapshot before submission.
  final int? activeStudentId;
  final String? activeStudentLabel;

  const LeavingNoticeResult({
    required this.success,
    this.error,
    this.leavingDate,
    this.minLeavingDate,
    this.activeStudentId,
    this.activeStudentLabel,
  });

  factory LeavingNoticeResult.failure(String message) =>
      LeavingNoticeResult(success: false, error: message);

  factory LeavingNoticeResult.fromJson(Map<String, dynamic> json) {
    return LeavingNoticeResult(
      success: json['success'] == true,
      error: json['error']?.toString(),
      leavingDate: _parseDate(json['leaving_date']),
      minLeavingDate: _parseDate(json['min_leaving_date']),
      activeStudentId: _parseInt(json['active_student_id']),
      activeStudentLabel: json['active_student_label']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) return raw > 0 ? raw.toInt() : null;
    final n = int.tryParse(raw.toString());
    return (n != null && n > 0) ? n : null;
  }
}

/// Repository for the "End Subscription" / Leaving Notice flow.
///
/// Called from the *logged-in* parent's profile menu — the request
/// authenticates with the same scheme the rest of `parent_link/*` uses
/// (`caller_user_type='app_parent'` + `caller_user_id=app_parents.id`), so
/// the parent doesn't have to re-enter their password.
///
/// On successful submission we also cache the leaving date locally, keyed
/// by `app_parents.id`. The dashboard profile menu reads that cache to
/// grey out the "End Subscription" tile once the leaving date has been
/// reached — purely a visual hint; the server is the source of truth for
/// subscription state.
class ParentLeavingRepository {
  static const String _userType = 'app_parent';

  // Prefix; appended with the `app_parents.id` so the cache survives across
  // logins/devices for the same parent.
  static const String _kPrefsPrefix = 'leaving_notice_date:';

  /// Submit a leaving notice. The server enforces that [leavingDate] is at
  /// least 28 days from today, but the UI date picker should match.
  ///
  /// [activeStudentId] is the `students.id` the parent has selected in the
  /// dashboard at submission time. It's stored audit-only — the server
  /// validates the student actually belongs to this parent and otherwise
  /// silently drops it (the notice itself is still saved).
  ///
  /// On success the leaving date is cached locally against [appParentId] so
  /// [getCachedLeavingDate] / [isSubscriptionEnded] can answer quickly.
  static Future<LeavingNoticeResult> submit({
    required int appParentId,
    required String reason,
    required DateTime leavingDate,
    int? activeStudentId,
  }) async {
    final trimmedReason = reason.trim();

    if (appParentId <= 0) {
      return LeavingNoticeResult.failure('Missing or invalid parent id.');
    }
    if (trimmedReason.isEmpty) {
      return LeavingNoticeResult.failure(
        'Please enter a reason for leaving.',
      );
    }

    final dateOnly = _yyyyMmDd(leavingDate);

    try {
      final body = <String, dynamic>{
        'caller_user_type': _userType,
        'caller_user_id': appParentId,
        'reason': trimmedReason,
        'leaving_date': dateOnly,
      };
      if (activeStudentId != null && activeStudentId > 0) {
        body['active_student_id'] = activeStudentId;
      }

      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/submit_leaving_notice.php',
        body: body,
      );
      final result = LeavingNoticeResult.fromJson(r);
      if (result.success) {
        final effective = result.leavingDate ?? leavingDate;
        await _cacheLeavingDate(appParentId, effective);
      }
      return result;
    } on ApiException catch (e) {
      debugPrint('ParentLeavingRepository.submit: ${e.message}');
      return LeavingNoticeResult.failure(e.message);
    }
  }

  /// Returns the cached leaving date for [appParentId], or `null` if none
  /// has been recorded on this device.
  static Future<DateTime?> getCachedLeavingDate({
    required int appParentId,
  }) async {
    final key = _prefsKey(appParentId);
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      debugPrint('ParentLeavingRepository.getCachedLeavingDate: $e');
      return null;
    }
  }

  /// Convenience: `true` when [appParentId] has a cached leaving date that
  /// is on or before today (date-only comparison, time of day ignored).
  static Future<bool> isSubscriptionEnded({
    required int appParentId,
  }) async {
    final date = await getCachedLeavingDate(appParentId: appParentId);
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOnly = DateTime(date.year, date.month, date.day);
    return !today.isBefore(dayOnly);
  }

  static Future<void> _cacheLeavingDate(int appParentId, DateTime date) async {
    final key = _prefsKey(appParentId);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, _yyyyMmDd(date));
    } catch (e) {
      debugPrint('ParentLeavingRepository._cacheLeavingDate: $e');
    }
  }

  static String? _prefsKey(int appParentId) {
    if (appParentId <= 0) return null;
    return '$_kPrefsPrefix$appParentId';
  }

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
