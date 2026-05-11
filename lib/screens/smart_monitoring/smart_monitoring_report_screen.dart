import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/smart_monitoring/smart_monitoring_models.dart';
import 'package:learining_portal/network/domain/smart_monitoring_repository.dart';
import 'package:learining_portal/screens/smart_monitoring/widgets/sm_theme.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Mobile equivalent of `admin/smartmonitoring/report.php` — full visual
/// report for a single student over a chosen period, with fl_chart-driven
/// score ring, radar, bar, attendance pie, HW old-vs-new comparison and
/// numeric metric cards.
class SmartMonitoringReportScreen extends StatefulWidget {
  const SmartMonitoringReportScreen({
    super.key,
    required this.studentId,
    required this.fallbackName,
    required this.from,
    required this.to,
    required this.callerStaffId,
    this.initialSnapshot,
  });

  final int studentId;
  final String fallbackName;
  final DateTime from;
  final DateTime to;
  final int callerStaffId;
  final SmartMonitoringSnapshot? initialSnapshot;

  @override
  State<SmartMonitoringReportScreen> createState() =>
      _SmartMonitoringReportScreenState();
}

class _SmartMonitoringReportScreenState
    extends State<SmartMonitoringReportScreen> {
  bool _loading = true;
  String? _error;
  SmartMonitoringSnapshot? _snapshot;
  bool _tableOk = true;
  bool _showCompositeAudit = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await SmartMonitoringRepository.getSnapshot(
      callerStaffId: widget.callerStaffId,
      studentId: widget.studentId,
      from: widget.from,
      to: widget.to,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tableOk = res.tableOk;
      if (res.snapshot != null) {
        _snapshot = res.snapshot;
      }
      if (!res.success) {
        _error = res.error ?? 'Failed to load report.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    final name = s?.fullName ?? widget.fallbackName;
    final subtitle =
        '${_formatYmd(widget.from)} → ${_formatYmd(widget.to)}';
    return SiThemedPageScaffold(
      title: name,
      subtitle: subtitle,
      child: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (!_tableOk) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          _MissingTableNote(),
        ],
      );
    }

    final s = _snapshot;
    if (s == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) _ErrorCard(message: _error!),
          const SizedBox(height: 12),
          const _NoSnapshotNote(),
        ],
      );
    }

    final m = s.metrics;
    final showHwSplit =
        m.homeworkLegacy.pct != null || m.homeworkAi.pct != null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
        ],
        _HeaderCard(snapshot: s),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Strengths radar',
          subtitle:
              'Homework / attendance / exams / engagement / feedback (0–100)',
          height: 280,
          child: _StrengthsRadar(metrics: m),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Pillar performance',
          subtitle: 'Side-by-side comparison of each headline metric',
          height: 240,
          child: _PillarBars(metrics: m),
        ),
        if (showHwSplit) ...[
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Homework: old vs new',
            subtitle: 'Legacy assignments vs AI homework completion',
            height: 220,
            child: _HomeworkOldNewBars(metrics: m),
          ),
        ],
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Attendance breakdown',
          subtitle: 'Days per attendance type in this period',
          height: 220,
          child: _AttendancePie(att: m.attendance),
        ),
        const SizedBox(height: 12),
        _MetricGrid(metrics: m),
        if (m.enrollments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EnrollmentsCard(enrollments: m.enrollments),
        ],
        if (s.suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SuggestionsCard(suggestions: s.suggestions),
        ],
        const SizedBox(height: 12),
        _CompositeAuditCard(
          metrics: m,
          expanded: _showCompositeAudit,
          onToggle: () =>
              setState(() => _showCompositeAudit = !_showCompositeAudit),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Header — name, score ring, status / trend / risk badges
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.snapshot});
  final SmartMonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scoreColor = SmartMonitoringPalette.colorForPct(snapshot.score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: _ScoreRing(score: snapshot.score, color: scoreColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (snapshot.admissionNo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Adm. ${snapshot.admissionNo}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ChipBadge(
                      label: snapshot.status.label,
                      color: SmartMonitoringPalette.statusColor(snapshot.status),
                    ),
                    _ChipBadge(
                      label: 'Trend ${snapshot.trend.label}',
                      color: snapshot.trend == SmartMonitoringTrend.up
                          ? SmartMonitoringPalette.good
                          : snapshot.trend == SmartMonitoringTrend.down
                              ? SmartMonitoringPalette.critical
                              : AppColors.textSecondary,
                    ),
                    _ChipBadge(
                      label: 'Risk ${snapshot.risk.label}',
                      color: snapshot.risk == SmartMonitoringRisk.critical
                          ? SmartMonitoringPalette.critical
                          : snapshot.risk == SmartMonitoringRisk.warning
                              ? SmartMonitoringPalette.warning
                              : AppColors.textSecondary,
                    ),
                  ],
                ),
                if (snapshot.previousScore != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Previous score: ${snapshot.previousScore!.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = (score.clamp(0, 100)) / 100.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 8,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.textSecondary.withOpacity(0.18),
            ),
          ),
        ),
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            Text(
              'Score',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Chart card wrapper
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.child,
  });

  final String title;
  final String subtitle;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Strengths radar
// ---------------------------------------------------------------------------

class _StrengthsRadar extends StatelessWidget {
  const _StrengthsRadar({required this.metrics});
  final SmartMonitoringMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final values = <double>[
      (metrics.homeworkBlendedPct ?? 0).clamp(0, 100).toDouble(),
      (metrics.attendance.pct ?? 0).clamp(0, 100).toDouble(),
      (metrics.examsBlendedPct ?? 0).clamp(0, 100).toDouble(),
      (metrics.engagement.pct ?? 0).clamp(0, 100).toDouble(),
      (metrics.termFeedback.scaledPct ?? 0).clamp(0, 100).toDouble(),
    ];
    const titles = ['Homework', 'Attendance', 'Exams', 'Engagement', 'Feedback'];

    if (values.every((v) => v == 0)) {
      return const _EmptyChartHint(
        message: 'Not enough data to draw the radar chart yet.',
      );
    }

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        titleTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        getTitle: (i, _) => RadarChartTitle(text: titles[i % titles.length]),
        ticksTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9,
        ),
        radarBorderData: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.4),
        ),
        gridBorderData: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.18),
        ),
        tickBorderData: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.accentTeal.withOpacity(0.30),
            borderColor: AppColors.accentTeal,
            borderWidth: 2,
            entryRadius: 3,
            dataEntries:
                values.map((v) => RadarEntry(value: v)).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Pillar bars
// ---------------------------------------------------------------------------

class _PillarBars extends StatelessWidget {
  const _PillarBars({required this.metrics});
  final SmartMonitoringMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final entries = <_LabeledValue>[
      _LabeledValue('Homework', metrics.homeworkBlendedPct),
      _LabeledValue('Attendance', metrics.attendance.pct),
      _LabeledValue('Exams', metrics.examsBlendedPct),
      _LabeledValue('Summaries', metrics.classSummaries.readPct),
      _LabeledValue('Engagement', metrics.engagement.pct),
    ];
    if (entries.every((e) => e.value == null)) {
      return const _EmptyChartHint(
        message: 'No metric data for this period yet.',
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        minY: 0,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textSecondary.withOpacity(0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entries[i].label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = entries[group.x.toInt()];
              final txt = e.value == null
                  ? '${e.label}: —'
                  : '${e.label}: ${e.value!.toStringAsFixed(1)}%';
              return BarTooltipItem(
                txt,
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (int i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value ?? 0,
                  color: SmartMonitoringPalette.colorForPct(entries[i].value),
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HomeworkOldNewBars extends StatelessWidget {
  const _HomeworkOldNewBars({required this.metrics});
  final SmartMonitoringMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final entries = <_LabeledValue>[
      _LabeledValue(
        'Old (legacy)',
        metrics.homeworkLegacy.pct,
      ),
      _LabeledValue(
        'New (AI)',
        metrics.homeworkAi.pct,
      ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: 100,
        minY: 0,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textSecondary.withOpacity(0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entries[i].label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, _, _) {
              final e = entries[g.x.toInt()];
              final txt = e.value == null
                  ? '${e.label}: —'
                  : '${e.label}: ${e.value!.toStringAsFixed(1)}%';
              return BarTooltipItem(
                txt,
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (int i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value ?? 0,
                  color: SmartMonitoringPalette.colorForPct(entries[i].value),
                  width: 32,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Attendance pie
// ---------------------------------------------------------------------------

class _AttendancePie extends StatefulWidget {
  const _AttendancePie({required this.att});
  final SmartMonitoringAttendance att;

  @override
  State<_AttendancePie> createState() => _AttendancePieState();
}

class _AttendancePieState extends State<_AttendancePie> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final att = widget.att;
    final total = att.totalRated + att.holiday;
    if (total <= 0) {
      return const _EmptyChartHint(
        message: 'No attendance data for this period yet.',
      );
    }

    final segments = <_PieSegment>[
      _PieSegment(
        'Present',
        att.present.toDouble(),
        const Color(0xFF16A34A),
      ),
      _PieSegment(
        'Excuse / late / half',
        (att.excuse + att.late + att.halfDay).toDouble(),
        const Color(0xFFCA8A04),
      ),
      _PieSegment(
        'Absent',
        att.absent.toDouble(),
        const Color(0xFFDC2626),
      ),
      _PieSegment(
        'Holiday',
        att.holiday.toDouble(),
        const Color(0xFF94A3B8),
      ),
    ].where((s) => s.value > 0).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              sections: [
                for (int i = 0; i < segments.length; i++)
                  PieChartSectionData(
                    value: segments[i].value,
                    color: segments[i].color,
                    radius: i == _touchedIndex ? 56 : 50,
                    title:
                        '${(100 * segments[i].value / total).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: segments
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s.label}: ${s.value.toInt()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Numeric metric grid
// ---------------------------------------------------------------------------

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final SmartMonitoringMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _MetricTile(
        icon: Icons.menu_book_rounded,
        label: 'Class summaries',
        primary:
            '${metrics.classSummaries.read} / ${metrics.classSummaries.eligible}',
        secondary: metrics.classSummaries.readPct == null
            ? 'No eligible summaries'
            : '${metrics.classSummaries.readPct!.toStringAsFixed(1)}% read',
        accent: SmartMonitoringPalette.colorForPct(
          metrics.classSummaries.readPct,
        ),
      ),
      _MetricTile(
        icon: Icons.style_rounded,
        label: 'Flashcards',
        primary:
            '${metrics.flashcards.completed} / ${metrics.flashcards.opened}',
        secondary: metrics.flashcards.completedPct == null
            ? 'No decks opened'
            : '${metrics.flashcards.completedPct!.toStringAsFixed(1)}% completed',
        accent: SmartMonitoringPalette.colorForPct(
          metrics.flashcards.completedPct,
        ),
      ),
      _MetricTile(
        icon: Icons.video_camera_front_rounded,
        label: 'Live classes (Zoom)',
        primary:
            '${metrics.zoom.joined} / ${metrics.zoom.scheduled}',
        secondary: metrics.zoom.joinedPct == null
            ? 'None scheduled'
            : '${metrics.zoom.joinedPct!.toStringAsFixed(1)}% joined',
        accent: SmartMonitoringPalette.colorForPct(metrics.zoom.joinedPct),
      ),
      _MetricTile(
        icon: Icons.quiz_rounded,
        label: 'Online exams',
        primary:
            '${metrics.onlineExams.attempted} / ${metrics.onlineExams.assigned}',
        secondary: metrics.onlineExams.avgPct == null
            ? 'No score data'
            : 'Avg ${metrics.onlineExams.avgPct!.toStringAsFixed(1)}%',
        accent:
            SmartMonitoringPalette.colorForPct(metrics.onlineExams.avgPct),
      ),
      _MetricTile(
        icon: Icons.assessment_rounded,
        label: 'Transcript exams',
        primary: metrics.transcriptExams.avgPct == null
            ? '—'
            : '${metrics.transcriptExams.avgPct!.toStringAsFixed(1)}%',
        secondary: '${metrics.transcriptExams.attempts} attempt(s)',
        accent: SmartMonitoringPalette.colorForPct(
          metrics.transcriptExams.avgPct,
        ),
      ),
      _MetricTile(
        icon: Icons.star_rounded,
        label: 'Term feedback',
        primary: metrics.termFeedback.avgRating == null
            ? '—'
            : '${metrics.termFeedback.avgRating!.toStringAsFixed(2)} / 5',
        secondary: 'Stored separately, not in score',
        accent: AppColors.accentTeal,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 170.0;
        final maxCols =
            (constraints.maxWidth / minWidth).floor().clamp(1, 3);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tiles)
              SizedBox(
                width: (constraints.maxWidth - (maxCols - 1) * 10) / maxCols,
                child: t,
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String primary;
  final String secondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            primary,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Other helper sections
// ---------------------------------------------------------------------------

class _EnrollmentsCard extends StatelessWidget {
  const _EnrollmentsCard({required this.enrollments});
  final List<SmartMonitoringEnrollment> enrollments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Enrollments',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in enrollments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${e.className} · ${e.sectionName}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions});
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: Color(0xFF115E59)),
              const SizedBox(width: 8),
              Text(
                'Suggestions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF115E59),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 6),
                    child: Icon(
                      Icons.fiber_manual_record,
                      size: 6,
                      color: Color(0xFF115E59),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: Color(0xFF134E4A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompositeAuditCard extends StatelessWidget {
  const _CompositeAuditCard({
    required this.metrics,
    required this.expanded,
    required this.onToggle,
  });
  final SmartMonitoringMetrics metrics;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final inputs = metrics.compositeInputs;
    final keys = inputs.keys.toList()..sort();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Composite inputs (audit)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final k in keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              k,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Text(
                              _stringifyValue(inputs[k]),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                                height: 1.35,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _stringifyValue(dynamic v) {
    if (v == null) return 'null';
    if (v is num) return v.toString();
    if (v is bool) return v ? 'true' : 'false';
    if (v is String) {
      if (v.length > 160) {
        return '${v.substring(0, 157)}…';
      }
      return v;
    }
    if (v is Map || v is Iterable) {
      try {
        return v.toString();
      } catch (_) {
        return '';
      }
    }
    return v.toString();
  }
}

class _MissingTableNote extends StatelessWidget {
  const _MissingTableNote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9C46A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB07A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The student_monitoring_snapshots table is missing on the server. Run application/database/smart_monitoring_tables.sql first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6E4D00),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSnapshotNote extends StatelessWidget {
  const _NoSnapshotNote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              color: AppColors.textSecondary.withOpacity(0.6), size: 36),
          const SizedBox(height: 8),
          Text(
            'No snapshot for this period.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Run the cron or use the web "Rebuild all" button to compute the snapshot for this student.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              color: SmartMonitoringPalette.critical),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A1F1F),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  const _EmptyChartHint({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
      ),
    );
  }
}

class _LabeledValue {
  const _LabeledValue(this.label, this.value);
  final String label;
  final double? value;
}

class _PieSegment {
  const _PieSegment(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

String _formatYmd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
