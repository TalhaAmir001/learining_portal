// Data models for the Smart Monitoring feature (Super Admin only).
//
// Mirror the payloads of the `mobile_apis/get_smartmonitoring_*.php` endpoints,
// which themselves project rows from the `student_monitoring_snapshots` table
// produced by the web `Monitoring_model::build_metrics_payload()` pipeline.
//
// The PHP layer pre-decodes the `metrics` and `suggestions` JSON columns so
// Flutter just navigates nested maps — no double-decode here.

int _readInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _readNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

double? _readNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String _readStr(Map<String, dynamic> json, String key) =>
    (json[key] ?? '').toString();

Map<String, dynamic> _readMap(dynamic raw) {
  if (raw is Map) {
    return raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return <String, dynamic>{};
}

List<dynamic> _readList(dynamic raw) {
  if (raw is List) return raw;
  return const <dynamic>[];
}

/// Composite-status traffic light. Aligns with the `status` column in
/// `student_monitoring_snapshots`.
enum SmartMonitoringStatus { good, warning, critical;

  static SmartMonitoringStatus fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'good':
        return SmartMonitoringStatus.good;
      case 'critical':
        return SmartMonitoringStatus.critical;
      case 'warning':
      default:
        return SmartMonitoringStatus.warning;
    }
  }

  String get apiValue {
    switch (this) {
      case SmartMonitoringStatus.good:
        return 'good';
      case SmartMonitoringStatus.warning:
        return 'warning';
      case SmartMonitoringStatus.critical:
        return 'critical';
    }
  }

  String get label {
    switch (this) {
      case SmartMonitoringStatus.good:
        return 'Good';
      case SmartMonitoringStatus.warning:
        return 'Warning';
      case SmartMonitoringStatus.critical:
        return 'Critical';
    }
  }
}

/// Direction vs. the previous snapshot for the same student.
enum SmartMonitoringTrend { up, down, stable;

  static SmartMonitoringTrend fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'up':
        return SmartMonitoringTrend.up;
      case 'down':
        return SmartMonitoringTrend.down;
      case 'stable':
      default:
        return SmartMonitoringTrend.stable;
    }
  }

  String get label {
    switch (this) {
      case SmartMonitoringTrend.up:
        return 'Up';
      case SmartMonitoringTrend.down:
        return 'Down';
      case SmartMonitoringTrend.stable:
        return 'Stable';
    }
  }
}

/// Severity flag separate from `status` (e.g. low attendance can flip risk
/// to `critical` even if score still says `warning`).
enum SmartMonitoringRisk { normal, warning, critical;

  static SmartMonitoringRisk fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'critical':
        return SmartMonitoringRisk.critical;
      case 'warning':
        return SmartMonitoringRisk.warning;
      case 'normal':
      default:
        return SmartMonitoringRisk.normal;
    }
  }

  String get label {
    switch (this) {
      case SmartMonitoringRisk.normal:
        return 'Normal';
      case SmartMonitoringRisk.warning:
        return 'Warning';
      case SmartMonitoringRisk.critical:
        return 'Critical';
    }
  }
}

class SmartMonitoringClass {
  SmartMonitoringClass({required this.id, required this.name});
  final int id;
  final String name;

  factory SmartMonitoringClass.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringClass(
      id: _readInt(json, 'id'),
      name: _readStr(json, 'class_name'),
    );
  }
}

class SmartMonitoringSection {
  SmartMonitoringSection({required this.id, required this.name});
  final int id;
  final String name;

  factory SmartMonitoringSection.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringSection(
      id: _readInt(json, 'id'),
      name: _readStr(json, 'section_name'),
    );
  }
}

class SmartMonitoringAttendance {
  SmartMonitoringAttendance({
    required this.pct,
    required this.present,
    required this.excuse,
    required this.late,
    required this.absent,
    required this.halfDay,
    required this.holiday,
    required this.ratedDays,
  });

  final double? pct;
  final int present;
  final int excuse;
  final int late;
  final int absent;
  final int halfDay;
  final int holiday;
  final int ratedDays;

  factory SmartMonitoringAttendance.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringAttendance(
      pct: _readNullableDouble(json['pct']),
      present: _readInt(json, 'present'),
      excuse: _readInt(json, 'excuse'),
      late: _readInt(json, 'late'),
      absent: _readInt(json, 'absent'),
      halfDay: _readInt(json, 'half_day'),
      holiday: _readInt(json, 'holiday'),
      ratedDays: _readInt(json, 'rated_days'),
    );
  }

  /// Sum of rated days (matches the web's denominator for the percentage).
  int get totalRated =>
      ratedDays > 0 ? ratedDays : present + excuse + late + halfDay + absent;

  /// "Present-like" total used in the radar chart and pie.
  int get positive => present + excuse + late + halfDay;
}

class SmartMonitoringClassSummaries {
  SmartMonitoringClassSummaries({required this.eligible, required this.read});
  final int eligible;
  final int read;

  factory SmartMonitoringClassSummaries.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringClassSummaries(
      eligible: _readInt(json, 'eligible'),
      read: _readInt(json, 'read'),
    );
  }

  double? get readPct => eligible > 0
      ? (100.0 * read.clamp(0, eligible) / eligible)
      : null;
}

class SmartMonitoringFlashcards {
  SmartMonitoringFlashcards({required this.opened, required this.completed});
  final int opened;
  final int completed;

  factory SmartMonitoringFlashcards.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringFlashcards(
      opened: _readInt(json, 'opened'),
      completed: _readInt(json, 'completed'),
    );
  }

  double? get completedPct => opened > 0
      ? (100.0 * (completed > opened ? opened : completed) / opened)
      : null;
}

class SmartMonitoringZoom {
  SmartMonitoringZoom({required this.scheduled, required this.joined});
  final int scheduled;
  final int joined;

  factory SmartMonitoringZoom.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringZoom(
      scheduled: _readInt(json, 'scheduled'),
      joined: _readInt(json, 'joined'),
    );
  }

  double? get joinedPct =>
      scheduled > 0 ? (100.0 * joined.clamp(0, scheduled) / scheduled) : null;
}

class SmartMonitoringHomework {
  SmartMonitoringHomework({
    required this.assigned,
    required this.submitted,
    required this.pct,
  });
  final int assigned;
  final int submitted;
  final double? pct;

  factory SmartMonitoringHomework.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringHomework(
      assigned: _readInt(json, 'assigned'),
      submitted: _readInt(json, 'submitted'),
      pct: _readNullableDouble(json['pct']),
    );
  }
}

class SmartMonitoringTranscriptExams {
  SmartMonitoringTranscriptExams({required this.avgPct, required this.attempts});
  final double? avgPct;
  final int attempts;

  factory SmartMonitoringTranscriptExams.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringTranscriptExams(
      avgPct: _readNullableDouble(json['avg_pct']),
      attempts: _readInt(json, 'attempts'),
    );
  }
}

class SmartMonitoringOnlineExams {
  SmartMonitoringOnlineExams({
    required this.assigned,
    required this.attempted,
    required this.avgPct,
  });
  final int assigned;
  final int attempted;
  final double? avgPct;

  factory SmartMonitoringOnlineExams.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringOnlineExams(
      assigned: _readInt(json, 'assigned'),
      attempted: _readInt(json, 'attempted'),
      avgPct: _readNullableDouble(json['avg_pct']),
    );
  }
}

class SmartMonitoringTermFeedback {
  SmartMonitoringTermFeedback({required this.avgRating});
  final double? avgRating;

  factory SmartMonitoringTermFeedback.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringTermFeedback(
      avgRating: _readNullableDouble(json['avg_rating']),
    );
  }

  /// Maps the 1–5 average to a 0–100 percentage for radar/bar parity with
  /// the other metrics.
  double? get scaledPct =>
      avgRating == null ? null : (avgRating!.clamp(0, 5) / 5.0) * 100.0;
}

class SmartMonitoringEngagement {
  SmartMonitoringEngagement({
    required this.pct,
    required this.includedInComposite,
    required this.summaryReadPct,
  });
  final double? pct;
  final bool includedInComposite;
  final double? summaryReadPct;

  factory SmartMonitoringEngagement.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringEngagement(
      pct: _readNullableDouble(json['pct']),
      includedInComposite: json['included_in_composite'] == true,
      summaryReadPct: _readNullableDouble(json['summary_read_pct']),
    );
  }
}

class SmartMonitoringEnrollment {
  SmartMonitoringEnrollment({
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.studentSessionId,
  });
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final int studentSessionId;

  factory SmartMonitoringEnrollment.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringEnrollment(
      classId: _readInt(json, 'class_id'),
      sectionId: _readInt(json, 'section_id'),
      className: _readStr(json, 'class'),
      sectionName: _readStr(json, 'section'),
      studentSessionId: _readInt(json, 'student_session_id'),
    );
  }
}

/// Aggregated metrics block — mirrors the JSON written by
/// `Monitoring_model::build_metrics_payload()`.
class SmartMonitoringMetrics {
  SmartMonitoringMetrics({
    required this.attendance,
    required this.classSummaries,
    required this.flashcards,
    required this.zoom,
    required this.homeworkLegacy,
    required this.homeworkAi,
    required this.homeworkBlendedPct,
    required this.transcriptExams,
    required this.onlineExams,
    required this.examsBlendedPct,
    required this.termFeedback,
    required this.engagement,
    required this.enrollments,
    required this.compositeInputs,
  });

  final SmartMonitoringAttendance attendance;
  final SmartMonitoringClassSummaries classSummaries;
  final SmartMonitoringFlashcards flashcards;
  final SmartMonitoringZoom zoom;
  final SmartMonitoringHomework homeworkLegacy;
  final SmartMonitoringHomework homeworkAi;
  final double? homeworkBlendedPct;
  final SmartMonitoringTranscriptExams transcriptExams;
  final SmartMonitoringOnlineExams onlineExams;
  final double? examsBlendedPct;
  final SmartMonitoringTermFeedback termFeedback;
  final SmartMonitoringEngagement engagement;
  final List<SmartMonitoringEnrollment> enrollments;

  /// Free-form audit block from the server (transcript_exam_pct, online_exam_pct,
  /// nominal_weights, etc.). Kept as raw map so the report can list it.
  final Map<String, dynamic> compositeInputs;

  factory SmartMonitoringMetrics.fromJson(Map<String, dynamic> json) {
    final enr = _readList(json['enrollments'])
        .whereType<Map>()
        .map((e) => SmartMonitoringEnrollment.fromJson(
              e.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList(growable: false);
    return SmartMonitoringMetrics(
      attendance: SmartMonitoringAttendance.fromJson(_readMap(json['attendance'])),
      classSummaries:
          SmartMonitoringClassSummaries.fromJson(_readMap(json['class_summaries'])),
      flashcards: SmartMonitoringFlashcards.fromJson(_readMap(json['flashcards'])),
      zoom: SmartMonitoringZoom.fromJson(_readMap(json['zoom'])),
      homeworkLegacy:
          SmartMonitoringHomework.fromJson(_readMap(json['homework_legacy'])),
      homeworkAi: SmartMonitoringHomework.fromJson(_readMap(json['homework_ai'])),
      homeworkBlendedPct: _readNullableDouble(json['homework_blended_pct']),
      transcriptExams: SmartMonitoringTranscriptExams.fromJson(
        _readMap(json['transcript_exams']),
      ),
      onlineExams:
          SmartMonitoringOnlineExams.fromJson(_readMap(json['online_exams'])),
      examsBlendedPct: _readNullableDouble(json['exams_blended_pct']),
      termFeedback:
          SmartMonitoringTermFeedback.fromJson(_readMap(json['term_feedback'])),
      engagement: SmartMonitoringEngagement.fromJson(_readMap(json['engagement'])),
      enrollments: enr,
      compositeInputs: _readMap(json['composite_inputs']),
    );
  }
}

/// One row from `student_monitoring_snapshots` joined with `students.*`.
class SmartMonitoringSnapshot {
  SmartMonitoringSnapshot({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.firstname,
    required this.lastname,
    required this.admissionNo,
    required this.periodStart,
    required this.periodEnd,
    required this.score,
    required this.previousScore,
    required this.status,
    required this.trend,
    required this.risk,
    required this.computedAt,
    required this.metrics,
    required this.suggestions,
  });

  final int id;
  final int sessionId;
  final int studentId;
  final String firstname;
  final String lastname;
  final String admissionNo;
  final String periodStart;
  final String periodEnd;
  final double score;
  final double? previousScore;
  final SmartMonitoringStatus status;
  final SmartMonitoringTrend trend;
  final SmartMonitoringRisk risk;
  final String computedAt;
  final SmartMonitoringMetrics metrics;
  final List<String> suggestions;

  factory SmartMonitoringSnapshot.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringSnapshot(
      id: _readInt(json, 'id'),
      sessionId: _readInt(json, 'session_id'),
      studentId: _readInt(json, 'student_id'),
      firstname: _readStr(json, 'firstname'),
      lastname: _readStr(json, 'lastname'),
      admissionNo: _readStr(json, 'admission_no'),
      periodStart: _readStr(json, 'period_start'),
      periodEnd: _readStr(json, 'period_end'),
      score: _readNullableDouble(json['score']) ?? 0,
      previousScore: _readNullableDouble(json['previous_score']),
      status: SmartMonitoringStatus.fromString(_readStr(json, 'status')),
      trend: SmartMonitoringTrend.fromString(_readStr(json, 'trend')),
      risk: SmartMonitoringRisk.fromString(_readStr(json, 'risk_level')),
      computedAt: _readStr(json, 'computed_at'),
      metrics: SmartMonitoringMetrics.fromJson(_readMap(json['metrics'])),
      suggestions: _readList(json['suggestions'])
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  String get fullName {
    final fn = firstname.trim();
    final ln = lastname.trim();
    if (fn.isEmpty && ln.isEmpty) return 'Student #$studentId';
    return '$fn $ln'.trim();
  }
}

class SmartMonitoringTopSuggestion {
  SmartMonitoringTopSuggestion({required this.text, required this.count});
  final String text;
  final int count;

  factory SmartMonitoringTopSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringTopSuggestion(
      text: _readStr(json, 'text'),
      count: _readInt(json, 'count'),
    );
  }
}

class SmartMonitoringInsights {
  SmartMonitoringInsights({
    required this.n,
    required this.byStatus,
    required this.risk,
    required this.trend,
    required this.avgScore,
    required this.avgAttendance,
    required this.avgHomework,
    required this.avgExamsBlended,
    required this.topSuggestions,
  });

  final int n;
  final Map<String, int> byStatus;
  final Map<String, int> risk;
  final Map<String, int> trend;
  final double? avgScore;
  final double? avgAttendance;
  final double? avgHomework;
  final double? avgExamsBlended;
  final List<SmartMonitoringTopSuggestion> topSuggestions;

  factory SmartMonitoringInsights.fromJson(Map<String, dynamic> json) {
    Map<String, int> intMap(dynamic raw) {
      final m = _readMap(raw);
      return m.map<String, int>(
        (k, v) =>
            MapEntry(k, _readNullableInt(v) ?? 0),
      );
    }

    return SmartMonitoringInsights(
      n: _readInt(json, 'n'),
      byStatus: intMap(json['by_status']),
      risk: intMap(json['risk']),
      trend: intMap(json['trend']),
      avgScore: _readNullableDouble(json['avg_score']),
      avgAttendance: _readNullableDouble(json['avg_attendance']),
      avgHomework: _readNullableDouble(json['avg_homework']),
      avgExamsBlended: _readNullableDouble(json['avg_exams_blended']),
      topSuggestions: _readList(json['top_suggestions'])
          .whereType<Map>()
          .map((e) => SmartMonitoringTopSuggestion.fromJson(
                e.map<String, dynamic>(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              ))
          .toList(growable: false),
    );
  }

  factory SmartMonitoringInsights.empty() => SmartMonitoringInsights(
        n: 0,
        byStatus: const {'good': 0, 'warning': 0, 'critical': 0},
        risk: const {'normal': 0, 'warning': 0, 'critical': 0},
        trend: const {'up': 0, 'down': 0, 'stable': 0},
        avgScore: null,
        avgAttendance: null,
        avgHomework: null,
        avgExamsBlended: null,
        topSuggestions: const [],
      );

  int statusCount(SmartMonitoringStatus s) => byStatus[s.apiValue] ?? 0;

  int get elevatedRisk => (risk['warning'] ?? 0) + (risk['critical'] ?? 0);
}

class SmartMonitoringRollups {
  SmartMonitoringRollups({
    required this.avgScore,
    required this.byStatus,
    required this.n,
  });

  final double? avgScore;
  final Map<String, int> byStatus;
  final int n;

  factory SmartMonitoringRollups.fromJson(Map<String, dynamic> json) {
    final raw = _readMap(json['by_status']);
    final m = raw.map<String, int>(
      (k, v) => MapEntry(k, _readNullableInt(v) ?? 0),
    );
    return SmartMonitoringRollups(
      avgScore: _readNullableDouble(json['avg_score']),
      byStatus: m,
      n: _readInt(json, 'n'),
    );
  }

  factory SmartMonitoringRollups.empty() => SmartMonitoringRollups(
        avgScore: null,
        byStatus: const {'good': 0, 'warning': 0, 'critical': 0},
        n: 0,
      );
}

class SmartMonitoringPeriod {
  SmartMonitoringPeriod({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  factory SmartMonitoringPeriod.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic raw, DateTime fallback) {
      if (raw == null) return fallback;
      try {
        return DateTime.parse(raw.toString());
      } catch (_) {
        return fallback;
      }
    }

    final today = DateTime.now();
    final fallbackTo = DateTime(today.year, today.month, today.day);
    final fallbackFrom = fallbackTo.subtract(const Duration(days: 30));
    return SmartMonitoringPeriod(
      from: parse(json['from'], fallbackFrom),
      to: parse(json['to'], fallbackTo),
    );
  }
}

/// Top-level overview payload returned by `get_smartmonitoring_overview.php`.
class SmartMonitoringOverview {
  SmartMonitoringOverview({
    required this.success,
    required this.tableOk,
    required this.period,
    required this.classlist,
    required this.snapshots,
    required this.insights,
    required this.rollups,
    this.error,
  });

  final bool success;
  final bool tableOk;
  final SmartMonitoringPeriod period;
  final List<SmartMonitoringClass> classlist;
  final List<SmartMonitoringSnapshot> snapshots;
  final SmartMonitoringInsights insights;
  final SmartMonitoringRollups rollups;
  final String? error;

  factory SmartMonitoringOverview.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringOverview(
      success: json['success'] == true,
      tableOk: json['table_ok'] == true,
      period: SmartMonitoringPeriod.fromJson(_readMap(json['period'])),
      classlist: _readList(json['classlist'])
          .whereType<Map>()
          .map((e) => SmartMonitoringClass.fromJson(
                e.map<String, dynamic>(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              ))
          .toList(growable: false),
      snapshots: _readList(json['snapshots'])
          .whereType<Map>()
          .map((e) => SmartMonitoringSnapshot.fromJson(
                e.map<String, dynamic>(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              ))
          .toList(growable: false),
      insights:
          SmartMonitoringInsights.fromJson(_readMap(json['insights'])),
      rollups: SmartMonitoringRollups.fromJson(_readMap(json['rollups'])),
      error: json['error']?.toString(),
    );
  }

  factory SmartMonitoringOverview.error(String message) => SmartMonitoringOverview(
        success: false,
        tableOk: false,
        period: SmartMonitoringPeriod.fromJson(const {}),
        classlist: const [],
        snapshots: const [],
        insights: SmartMonitoringInsights.empty(),
        rollups: SmartMonitoringRollups.empty(),
        error: message,
      );
}

class SmartMonitoringSectionsPayload {
  SmartMonitoringSectionsPayload({
    required this.success,
    required this.sections,
    this.error,
  });

  final bool success;
  final List<SmartMonitoringSection> sections;
  final String? error;

  factory SmartMonitoringSectionsPayload.fromJson(Map<String, dynamic> json) {
    return SmartMonitoringSectionsPayload(
      success: json['success'] == true,
      sections: _readList(json['sections'])
          .whereType<Map>()
          .map((e) => SmartMonitoringSection.fromJson(
                e.map<String, dynamic>(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              ))
          .toList(growable: false),
      error: json['error']?.toString(),
    );
  }
}

class SmartMonitoringSnapshotPayload {
  SmartMonitoringSnapshotPayload({
    required this.success,
    required this.tableOk,
    required this.period,
    required this.snapshot,
    this.error,
  });

  final bool success;
  final bool tableOk;
  final SmartMonitoringPeriod period;
  final SmartMonitoringSnapshot? snapshot;
  final String? error;

  factory SmartMonitoringSnapshotPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['snapshot'];
    SmartMonitoringSnapshot? snap;
    if (raw is Map) {
      snap = SmartMonitoringSnapshot.fromJson(
        raw.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return SmartMonitoringSnapshotPayload(
      success: json['success'] == true,
      tableOk: json['table_ok'] == true,
      period: SmartMonitoringPeriod.fromJson(_readMap(json['period'])),
      snapshot: snap,
      error: json['error']?.toString(),
    );
  }
}
