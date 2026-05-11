// Data models for the "Parent Self-Link Children" mobile feature.
//
// The trust model is code-based: the school admin generates a 6-char
// `mobile_app_code` on each `students` row; the guardian enters that code
// in the app to claim the child. Outcomes are therefore strong-only — there
// is no admin-review path. The `LinkChildOutcome.pendingApproval` value is
// kept for forward compatibility but not produced by the current server.
//
// Mirrors the JSON shape returned by:
//   • mobile_apis/get_parent_children.php
//   • mobile_apis/link_child_request.php
//   • mobile_apis/set_active_child.php

class ParentChild {
  final int studentId;
  final String firstname;
  final String middlename;
  final String lastname;
  final String admissionNo;
  final String? dob;
  final String className;
  final String sectionName;
  final bool isActive;

  const ParentChild({
    required this.studentId,
    required this.firstname,
    this.middlename = '',
    this.lastname = '',
    this.admissionNo = '',
    this.dob,
    this.className = '',
    this.sectionName = '',
    this.isActive = true,
  });

  /// Best-effort full name for display.
  String get fullName {
    final parts = <String>[];
    if (firstname.isNotEmpty) parts.add(firstname);
    if (middlename.isNotEmpty) parts.add(middlename);
    if (lastname.isNotEmpty) parts.add(lastname);
    return parts.isEmpty ? 'Student #$studentId' : parts.join(' ');
  }

  /// "Class · Section" for compact rows.
  String get classLabel {
    if (className.isEmpty && sectionName.isEmpty) return '';
    if (className.isEmpty) return sectionName;
    if (sectionName.isEmpty) return className;
    return '$className · $sectionName';
  }

  static int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  static String _toStr(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  static bool _toBool(dynamic v, [bool def = true]) {
    if (v == null) return def;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    if (s == 'yes' || s == 'true' || s == '1') return true;
    if (s == 'no' || s == 'false' || s == '0') return false;
    return def;
  }

  factory ParentChild.fromJson(Map<String, dynamic> json) {
    return ParentChild(
      studentId: _toInt(json['student_id']),
      firstname: _toStr(json['firstname']),
      middlename: _toStr(json['middlename']),
      lastname: _toStr(json['lastname']),
      admissionNo: _toStr(json['admission_no']),
      dob: () {
        final raw = json['dob'];
        if (raw == null) return null;
        final s = raw.toString();
        return s.isEmpty ? null : s;
      }(),
      className: _toStr(json['class_name']),
      sectionName: _toStr(json['section_name']),
      isActive: _toBool(json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'firstname': firstname,
    'middlename': middlename,
    'lastname': lastname,
    'admission_no': admissionNo,
    'dob': dob,
    'class_name': className,
    'section_name': sectionName,
    'is_active': isActive,
  };
}

/// All possible outcomes of `link_child_request.php`. Wrapped in an enum so
/// the UI can branch with a single `switch` instead of stringly-typed checks.
enum LinkChildOutcome {
  linked,
  alreadyLinked,
  pendingApproval,
  rejected,
  unmatched;

  static LinkChildOutcome fromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'linked':
        return LinkChildOutcome.linked;
      case 'already_linked':
        return LinkChildOutcome.alreadyLinked;
      case 'pending_approval':
      case 'pending':
        return LinkChildOutcome.pendingApproval;
      case 'unmatched':
        return LinkChildOutcome.unmatched;
      case 'rejected':
      default:
        return LinkChildOutcome.rejected;
    }
  }

  /// True when the link succeeded right away (no admin action required).
  bool get isSuccess =>
      this == LinkChildOutcome.linked || this == LinkChildOutcome.alreadyLinked;

  /// True when the user can keep the form open + see an inline error.
  bool get isInlineError =>
      this == LinkChildOutcome.rejected || this == LinkChildOutcome.unmatched;
}

class LinkChildResult {
  final LinkChildOutcome outcome;
  final String? message;
  final ParentChild? child;

  const LinkChildResult({
    required this.outcome,
    this.message,
    this.child,
  });

  factory LinkChildResult.fromJson(Map<String, dynamic> json) {
    final outcome = LinkChildOutcome.fromString(json['status']?.toString());
    final raw = json['child'];
    final child = raw is Map<String, dynamic>
        ? ParentChild.fromJson(raw)
        : null;
    final msg = json['error']?.toString() ?? json['message']?.toString();
    return LinkChildResult(
      outcome: outcome,
      message: (msg != null && msg.isNotEmpty) ? msg : null,
      child: child,
    );
  }

  /// Local-only constructor for network/parse errors.
  factory LinkChildResult.error(String message) => LinkChildResult(
    outcome: LinkChildOutcome.rejected,
    message: message,
  );
}

class ParentChildrenPayload {
  final bool success;
  final List<ParentChild> children;
  final int? activeChildId;
  final String? error;

  const ParentChildrenPayload({
    required this.success,
    this.children = const [],
    this.activeChildId,
    this.error,
  });

  factory ParentChildrenPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['children'];
    final list = <ParentChild>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(ParentChild.fromJson(item));
        } else if (item is Map) {
          list.add(ParentChild.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final activeRaw = json['active_child_id'];
    int? activeId;
    if (activeRaw != null && activeRaw.toString().isNotEmpty) {
      activeId = ParentChild._toInt(activeRaw, 0);
      if (activeId == 0) activeId = null;
    }
    return ParentChildrenPayload(
      success: json['success'] == true,
      children: list,
      activeChildId: activeId,
      error: json['error']?.toString(),
    );
  }

  ParentChildrenPayload copyWith({
    bool? success,
    List<ParentChild>? children,
    int? activeChildId,
    bool clearActiveChildId = false,
    String? error,
  }) {
    return ParentChildrenPayload(
      success: success ?? this.success,
      children: children ?? this.children,
      activeChildId: clearActiveChildId ? null : (activeChildId ?? this.activeChildId),
      error: error ?? this.error,
    );
  }
}
