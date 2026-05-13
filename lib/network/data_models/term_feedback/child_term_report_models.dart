// Data models for the parent-facing "Term Report" view.
//
// Mirrors the payload of `mobile_apis/get_child_term_reports.php`. The parent
// view is strictly read-only — the entry shape includes a few extra context
// fields the staff-side editor doesn't need (period, class/section frozen at
// save time, teacher's display name) so each report card is self-contained.

import 'package:learining_portal/network/data_models/term_feedback/term_feedback_models.dart';

int? _readNullableInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String _readStr(Map<String, dynamic> json, String key) =>
    (json[key] ?? '').toString();

/// Lightweight header for the active child — name + admission + current
/// class. Driven from the server so the report screen shows the same
/// class/section as the rest of the app.
class ChildTermReportHeader {
  ChildTermReportHeader({
    required this.studentId,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.admissionNo,
    required this.className,
    required this.sectionName,
  });

  final int studentId;
  final String firstname;
  final String middlename;
  final String lastname;
  final String admissionNo;
  final String className;
  final String sectionName;

  String get fullName {
    final parts = <String>[];
    if (firstname.isNotEmpty) parts.add(firstname);
    if (middlename.isNotEmpty) parts.add(middlename);
    if (lastname.isNotEmpty) parts.add(lastname);
    return parts.isEmpty ? 'Student #$studentId' : parts.join(' ');
  }

  String get classLabel {
    if (className.isEmpty && sectionName.isEmpty) return '';
    if (className.isEmpty) return sectionName;
    if (sectionName.isEmpty) return className;
    return '$className · $sectionName';
  }

  factory ChildTermReportHeader.fromJson(Map<String, dynamic> json) {
    return ChildTermReportHeader(
      studentId: _readNullableInt(json['student_id']) ?? 0,
      firstname: _readStr(json, 'firstname'),
      middlename: _readStr(json, 'middlename'),
      lastname: _readStr(json, 'lastname'),
      admissionNo: _readStr(json, 'admission_no'),
      className: _readStr(json, 'class_name'),
      sectionName: _readStr(json, 'section_name'),
    );
  }
}

/// A single saved term-feedback row, as the parent sees it. Ratings are
/// nullable because staff may save remarks without filling every score.
class ChildTermReportEntry {
  ChildTermReportEntry({
    required this.id,
    required this.periodStartMonth,
    required this.periodEndMonth,
    required this.participation,
    required this.behaviour,
    required this.classwork,
    required this.confidence,
    required this.homework,
    required this.remarks,
    required this.overall,
    required this.className,
    required this.sectionName,
    required this.teacherName,
    required this.updatedAt,
  });

  final int id;

  /// "YYYY-MM" — first month of the reporting window (inclusive).
  final String periodStartMonth;

  /// "YYYY-MM" — last month of the reporting window (inclusive).
  final String periodEndMonth;

  final int? participation;
  final int? behaviour;
  final int? classwork;
  final int? confidence;
  final int? homework;

  final String remarks;
  final TermFeedbackOverall? overall;
  final String className;
  final String sectionName;

  /// "First Last" of the staff member who saved this row, or empty when the
  /// row was authored by admin (no `teacher_staff_id`).
  final String teacherName;

  /// MySQL `updated_at` in `YYYY-MM-DD HH:MM:SS`. Empty when missing.
  final String updatedAt;

  /// "Class · Section" frozen at save time.
  String get classLabel {
    if (className.isEmpty && sectionName.isEmpty) return '';
    if (className.isEmpty) return sectionName;
    if (sectionName.isEmpty) return className;
    return '$className · $sectionName';
  }

  /// Has at least one numeric rating set — used to decide whether to render
  /// the rating section vs. just the remarks block.
  bool get hasAnyRating =>
      participation != null ||
      behaviour != null ||
      classwork != null ||
      confidence != null ||
      homework != null;

  /// Average of the populated ratings, on the same 1-5 scale; null when no
  /// rating is filled in. Used for the per-card "overall score" pill.
  double? get averageRating {
    final values = <int>[];
    if (participation != null) values.add(participation!);
    if (behaviour != null) values.add(behaviour!);
    if (classwork != null) values.add(classwork!);
    if (confidence != null) values.add(confidence!);
    if (homework != null) values.add(homework!);
    if (values.isEmpty) return null;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return sum / values.length;
  }

  factory ChildTermReportEntry.fromJson(Map<String, dynamic> json) {
    return ChildTermReportEntry(
      id: _readNullableInt(json['id']) ?? 0,
      periodStartMonth: _readStr(json, 'period_start_month'),
      periodEndMonth: _readStr(json, 'period_end_month'),
      participation: _readNullableInt(json['participation_rating']),
      behaviour: _readNullableInt(json['behaviour_rating']),
      classwork: _readNullableInt(json['classwork_rating']),
      confidence: _readNullableInt(json['confidence_rating']),
      homework: _readNullableInt(json['homework_rating']),
      remarks: _readStr(json, 'remarks'),
      overall: TermFeedbackOverall.fromApi(
        json['overall_class_performance']?.toString(),
      ),
      className: _readStr(json, 'class_name'),
      sectionName: _readStr(json, 'section_name'),
      teacherName: _readStr(json, 'teacher_name'),
      updatedAt: _readStr(json, 'updated_at'),
    );
  }
}

class ChildTermReportPayload {
  ChildTermReportPayload({
    required this.success,
    this.child,
    this.reports = const [],
    this.error,
  });

  final bool success;
  final ChildTermReportHeader? child;
  final List<ChildTermReportEntry> reports;
  final String? error;

  factory ChildTermReportPayload.fromJson(Map<String, dynamic> json) {
    final ok = json['success'] == true;
    ChildTermReportHeader? child;
    final raw = json['child'];
    if (raw is Map<String, dynamic>) {
      child = ChildTermReportHeader.fromJson(raw);
    } else if (raw is Map) {
      child = ChildTermReportHeader.fromJson(Map<String, dynamic>.from(raw));
    }
    final list = <ChildTermReportEntry>[];
    final reports = json['reports'];
    if (reports is List) {
      for (final item in reports) {
        if (item is Map<String, dynamic>) {
          list.add(ChildTermReportEntry.fromJson(item));
        } else if (item is Map) {
          list.add(ChildTermReportEntry.fromJson(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }
    return ChildTermReportPayload(
      success: ok,
      child: child,
      reports: list,
      error: json['error']?.toString(),
    );
  }
}

/// One *published* term-report PDF row, as the parent sees it. Backed by
/// `student_term_reports` on the server; the mobile app never sees drafts.
///
/// The actual bytes are not in this model — call
/// `TermFeedbackRepository.downloadPublishedReportPdf` to fetch them from
/// `mobile_apis/view_term_report_pdf.php` for rendering in an embedded
/// viewer.
class ChildPublishedTermReport {
  ChildPublishedTermReport({
    required this.id,
    required this.termNumber,
    required this.periodStartMonth,
    required this.periodEndMonth,
    required this.status,
    required this.publishedAt,
    required this.downloadAllowed,
  });

  /// `student_term_reports.id` — used to fetch the PDF.
  final int id;

  /// 1, 2 or 3 — used for colour-coding the card.
  final int termNumber;

  /// "YYYY-MM" — first month of the term window (inclusive).
  final String periodStartMonth;

  /// "YYYY-MM" — last month of the term window (inclusive).
  final String periodEndMonth;

  /// Server-side status. Should always be 'published' for parents — drafts
  /// are filtered out by the endpoint. Kept on the model for completeness.
  final String status;

  /// MySQL timestamp ("YYYY-MM-DD HH:MM:SS") when staff published the row.
  final String publishedAt;

  /// True when the admin enabled save-to-device for this report. The mobile
  /// app shows a small "Download" affordance in that case, but the default
  /// flow stays view-only.
  final bool downloadAllowed;

  /// Display label, e.g. "Term 1".
  String get termLabel => termNumber >= 1 && termNumber <= 3
      ? 'Term $termNumber'
      : 'Term';

  factory ChildPublishedTermReport.fromJson(Map<String, dynamic> json) {
    bool readBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v.toInt() != 0;
      final s = v?.toString().toLowerCase().trim() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    return ChildPublishedTermReport(
      id: _readNullableInt(json['id']) ?? 0,
      termNumber: _readNullableInt(json['term_number']) ?? 0,
      periodStartMonth: _readStr(json, 'period_start_month'),
      periodEndMonth: _readStr(json, 'period_end_month'),
      status: _readStr(json, 'status'),
      publishedAt: _readStr(json, 'published_at'),
      downloadAllowed: readBool(json['download_allowed']),
    );
  }
}

class ChildPublishedReportsPayload {
  ChildPublishedReportsPayload({
    required this.success,
    this.child,
    this.reports = const [],
    this.error,
  });

  final bool success;
  final ChildTermReportHeader? child;
  final List<ChildPublishedTermReport> reports;
  final String? error;

  factory ChildPublishedReportsPayload.fromJson(Map<String, dynamic> json) {
    final ok = json['success'] == true;
    ChildTermReportHeader? child;
    final raw = json['child'];
    if (raw is Map<String, dynamic>) {
      child = ChildTermReportHeader.fromJson(raw);
    } else if (raw is Map) {
      child = ChildTermReportHeader.fromJson(Map<String, dynamic>.from(raw));
    }
    final list = <ChildPublishedTermReport>[];
    final reports = json['reports'];
    if (reports is List) {
      for (final item in reports) {
        if (item is Map<String, dynamic>) {
          list.add(ChildPublishedTermReport.fromJson(item));
        } else if (item is Map) {
          list.add(ChildPublishedTermReport.fromJson(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }
    return ChildPublishedReportsPayload(
      success: ok,
      child: child,
      reports: list,
      error: json['error']?.toString(),
    );
  }
}
