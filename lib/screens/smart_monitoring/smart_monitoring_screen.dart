import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/smart_monitoring/smart_monitoring_models.dart';
import 'package:learining_portal/network/domain/smart_monitoring_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/smart_monitoring/smart_monitoring_report_screen.dart';
import 'package:learining_portal/screens/smart_monitoring/widgets/sm_theme.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Mobile equivalent of `admin/smartmonitoring/index.php` (Super Admin only).
///
/// Lets a Super Admin pick a date range + class/section/status/search filter
/// and view the snapshot list with KPI hero, top suggestions, and per-student
/// summary cards. Tapping a card opens [SmartMonitoringReportScreen] for the
/// full visual report.
class SmartMonitoringScreen extends StatefulWidget {
  const SmartMonitoringScreen({super.key});

  @override
  State<SmartMonitoringScreen> createState() => _SmartMonitoringScreenState();
}

class _SmartMonitoringScreenState extends State<SmartMonitoringScreen> {
  late DateTime _from;
  late DateTime _to;
  int _classId = 0;
  int _sectionId = 0;
  String _status = '';
  String _q = '';
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _loadingSections = false;
  bool _scoreLegendOpen = false;

  String? _error;
  SmartMonitoringOverview? _overview;
  List<SmartMonitoringSection> _sections = const [];
  int _staffId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    _staffId = auth.portalStaffId ?? 0;
    if (_staffId < 1) {
      setState(() {
        _loading = false;
        _error = 'Smart Monitoring is restricted to Super Admin.';
      });
      return;
    }
    await _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final overview = await SmartMonitoringRepository.getOverview(
      callerStaffId: _staffId,
      from: _from,
      to: _to,
      classId: _classId,
      sectionId: _sectionId,
      status: _status,
      q: _q,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!overview.success) {
        _error = overview.error ?? 'Failed to load Smart Monitoring data.';
      }
      _overview = overview;
    });
  }

  Future<void> _loadSections(int classId) async {
    if (classId < 1) {
      setState(() {
        _sections = const [];
        _sectionId = 0;
      });
      return;
    }
    setState(() => _loadingSections = true);
    final res = await SmartMonitoringRepository.getSections(
      callerStaffId: _staffId,
      classId: classId,
    );
    if (!mounted) return;
    setState(() {
      _loadingSections = false;
      _sections = res.sections;
      if (_sectionId > 0 &&
          !_sections.any((s) => s.id == _sectionId)) {
        _sectionId = 0;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final earliest = DateTime(2015);
    final latest = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: latest,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) {
          _to = _from;
        }
      } else {
        _to = picked;
        if (_to.isBefore(_from)) {
          _from = _to;
        }
      }
    });
  }

  void _applyFilters() {
    _q = _searchController.text.trim();
    _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Smart Monitoring',
      subtitle:
          'Engagement and performance snapshots (last $_periodDaysLabel days by default).',
      child: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: _loadOverview,
        child: _buildBody(),
      ),
    );
  }

  String get _periodDaysLabel {
    final diff = _to.difference(_from).inDays.abs();
    return diff.toString();
  }

  Widget _buildBody() {
    if (_loading && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final overview = _overview;
    if (_error != null && (overview == null || overview.snapshots.isEmpty)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _filtersCard(),
          const SizedBox(height: 12),
          _errorCard(_error!),
        ],
      );
    }

    if (overview == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _heroCard(overview),
        const SizedBox(height: 12),
        if (_error != null) ...[
          _errorCard(_error!),
          const SizedBox(height: 12),
        ],
        if (!overview.tableOk)
          _missingTableCard()
        else ...[
          _kpiStrip(overview),
          const SizedBox(height: 12),
          _scoreLegendCard(),
          const SizedBox(height: 12),
          _filtersCard(),
          const SizedBox(height: 12),
          if (overview.insights.topSuggestions.isNotEmpty) ...[
            _topSuggestionsCard(overview.insights),
            const SizedBox(height: 12),
          ],
          if (overview.snapshots.isEmpty)
            _emptyStateCard()
          else
            ...overview.snapshots.map(_snapshotCard),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Hero ----------------------------------------------------------------

  Widget _heroCard(SmartMonitoringOverview overview) {
    final ins = overview.insights;
    final periodText =
        '${_formatYmd(overview.period.from)} → ${_formatYmd(overview.period.to)}';
    final lines = <Widget>[
      Text(
        'At-a-glance',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
      ),
      const SizedBox(height: 4),
      Text(
        periodText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 4),
    ];
    if (ins.n > 0) {
      lines.add(Text(
        '${ins.n} student${ins.n == 1 ? '' : 's'} in this view'
        '${ins.avgScore != null ? ' · Avg score ${ins.avgScore}' : ''}'
        '${ins.avgAttendance != null ? ' · Avg attendance ${ins.avgAttendance}%' : ''}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
      ));
    } else {
      lines.add(Text(
        'No rows match your filters for this period.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
      ));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D5C56), Color(0xFF0F4F4A), Color(0xFF0C1929)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...lines,
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _HeroPill(text: 'HW + Attendance = core'),
              _HeroPill(text: 'Suggestions = actionable hints'),
            ],
          ),
        ],
      ),
    );
  }

  // ---- KPI strip ----------------------------------------------------------

  Widget _kpiStrip(SmartMonitoringOverview overview) {
    final ins = overview.insights;
    final tiles = <Widget>[
      _KpiTile(
        label: 'Avg score',
        value: ins.avgScore?.toStringAsFixed(1) ?? '—',
        accent: AppColors.accentTeal,
      ),
      _KpiTile(
        label: 'Good',
        value: ins.statusCount(SmartMonitoringStatus.good).toString(),
        accent: SmartMonitoringPalette.good,
      ),
      _KpiTile(
        label: 'Warning',
        value: ins.statusCount(SmartMonitoringStatus.warning).toString(),
        accent: SmartMonitoringPalette.warning,
      ),
      _KpiTile(
        label: 'Critical',
        value: ins.statusCount(SmartMonitoringStatus.critical).toString(),
        accent: SmartMonitoringPalette.critical,
      ),
      _KpiTile(
        label: 'Elevated risk',
        value: ins.elevatedRisk.toString(),
        accent: AppColors.secondaryPurple,
      ),
      _KpiTile(
        label: 'Trend ↑/↓',
        value:
            '${ins.trend['up'] ?? 0} / ${ins.trend['down'] ?? 0}',
        accent: AppColors.primaryBlue,
      ),
      _KpiTile(
        label: 'All in period',
        value: overview.rollups.n.toString(),
        accent: AppColors.textSecondary,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => tiles[i],
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: tiles.length,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _scoreLegendCard() {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _scoreLegendOpen = !_scoreLegendOpen),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.18),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'How the score is built',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(
                    _scoreLegendOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (_scoreLegendOpen) ...[
                const SizedBox(height: 8),
                Text(
                  'Nominal weights: homework 43% + attendance 43% + blended exams 10% + engagement 4%. '
                  'Only metrics that exist for that student are used — weights renormalize (missing homework is not treated as 0%). '
                  'Blended exams = average of transcript and online exam % when both exist, otherwise whichever exists. '
                  'Term feedback ratings are stored in each row but do not change the composite.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---- Filters ------------------------------------------------------------

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppColors.primaryBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Period from',
                  value: _from,
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'Period to',
                  value: _to,
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _classDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _sectionDropdown()),
            ],
          ),
          const SizedBox(height: 10),
          _statusDropdown(),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: SiChrome.inputDecoration(
              context,
              labelText: 'Student search',
              hintText: 'Name or admission no.',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading ? null : _applyFilters,
              icon: const Icon(Icons.filter_alt_rounded, size: 18),
              label: Text(_loading ? 'Loading…' : 'Apply filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classDropdown() {
    final overview = _overview;
    final classes = overview?.classlist ?? const <SmartMonitoringClass>[];
    return DropdownButtonFormField<int>(
      value: _classId == 0 ? 0 : (classes.any((c) => c.id == _classId) ? _classId : 0),
      decoration: SiChrome.inputDecoration(
        context,
        labelText: 'Class',
        prefixIcon: const Icon(Icons.school_rounded, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('All classes')),
        ...classes.map(
          (c) => DropdownMenuItem(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) {
        final next = v ?? 0;
        setState(() {
          _classId = next;
          _sectionId = 0;
          _sections = const [];
        });
        _loadSections(next);
      },
    );
  }

  Widget _sectionDropdown() {
    final hasSections = _sections.isNotEmpty;
    final value = _sectionId == 0
        ? 0
        : (_sections.any((s) => s.id == _sectionId) ? _sectionId : 0);
    return DropdownButtonFormField<int>(
      value: value,
      decoration: SiChrome.inputDecoration(
        context,
        labelText: _loadingSections ? 'Loading sections…' : 'Section',
        prefixIcon: const Icon(Icons.layers_rounded, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('All sections')),
        ..._sections.map(
          (s) => DropdownMenuItem(
            value: s.id,
            child: Text(s.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: !hasSections || _loadingSections
          ? null
          : (v) => setState(() => _sectionId = v ?? 0),
    );
  }

  Widget _statusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: SiChrome.inputDecoration(
        context,
        labelText: 'Status',
        prefixIcon: const Icon(Icons.flag_rounded, size: 20),
      ),
      items: const [
        DropdownMenuItem(value: '', child: Text('Any')),
        DropdownMenuItem(value: 'good', child: Text('Good')),
        DropdownMenuItem(value: 'warning', child: Text('Warning')),
        DropdownMenuItem(value: 'critical', child: Text('Critical')),
      ],
      onChanged: (v) => setState(() => _status = v ?? ''),
    );
  }

  // ---- Top suggestions ----------------------------------------------------

  Widget _topSuggestionsCard(SmartMonitoringInsights ins) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: AppColors.accentTeal),
              const SizedBox(width: 8),
              Text(
                'Most common suggestions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ins.topSuggestions
                .map(
                  (s) => Chip(
                    label: Text(
                      '${s.text}  ×${s.count}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.accentTeal.withOpacity(0.08),
                    side: BorderSide(
                      color: AppColors.accentTeal.withOpacity(0.4),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---- Snapshot card ------------------------------------------------------

  Widget _snapshotCard(SmartMonitoringSnapshot s) {
    final m = s.metrics;
    final cardColor = SmartMonitoringPalette.statusColor(s.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openReport(s),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.16),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: cardColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _snapshotHeader(s),
                          const SizedBox(height: 10),
                          _snapshotMetricsRow(s, m),
                          if (s.suggestions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _snapshotSuggestions(s.suggestions),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _snapshotHeader(SmartMonitoringSnapshot s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.fullName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (s.admissionNo.isNotEmpty)
                Text(
                  s.admissionNo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (s.score.clamp(0, 100) / 100),
                  minHeight: 5,
                  backgroundColor:
                      AppColors.textSecondary.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SmartMonitoringPalette.statusColor(s.status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _snapshotMetricsRow(
    SmartMonitoringSnapshot s,
    SmartMonitoringMetrics m,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SmStatusBadge.fromStatus(s.status),
        _SmTrendBadge(s.trend, previous: s.previousScore),
        _SmRiskBadge(s.risk),
        _SmStatChip(
          icon: Icons.event_available_rounded,
          label: m.attendance.pct != null
              ? '${m.attendance.pct!.toStringAsFixed(1)}%'
              : '—',
          tooltip: 'Attendance',
        ),
        _SmStatChip(
          icon: Icons.assignment_turned_in_rounded,
          label: m.homeworkBlendedPct != null
              ? '${m.homeworkBlendedPct!.toStringAsFixed(1)}%'
              : '—',
          tooltip: 'Homework',
        ),
        _SmStatChip(
          icon: Icons.school_rounded,
          label: m.examsBlendedPct != null
              ? '${m.examsBlendedPct!.toStringAsFixed(1)}%'
              : '—',
          tooltip: 'Exams (blended)',
        ),
        _SmStatChip(
          icon: Icons.menu_book_rounded,
          label:
              '${m.classSummaries.read}/${m.classSummaries.eligible}',
          tooltip: 'Summaries read / eligible',
        ),
        if (m.flashcards.completedPct != null)
          _SmStatChip(
            icon: Icons.style_rounded,
            label: '${m.flashcards.completedPct!.toStringAsFixed(0)}%',
            tooltip: 'Flashcards',
          ),
        if (m.termFeedback.avgRating != null)
          _SmStatChip(
            icon: Icons.star_rounded,
            label: '${m.termFeedback.avgRating!.toStringAsFixed(1)}/5',
            tooltip: 'Term feedback',
          ),
      ],
    );
  }

  Widget _snapshotSuggestions(List<String> suggestions) {
    final shown = suggestions.take(2).toList();
    final more = suggestions.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 6),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 6,
                    color: AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    s,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+$more more — open report',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }

  void _openReport(SmartMonitoringSnapshot s) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SmartMonitoringReportScreen(
          studentId: s.studentId,
          fallbackName: s.fullName,
          from: _from,
          to: _to,
          callerStaffId: _staffId,
          initialSnapshot: s,
        ),
      ),
    );
  }

  // ---- States -------------------------------------------------------------

  Widget _missingTableCard() {
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

  Widget _emptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              color: AppColors.textSecondary.withOpacity(0.6), size: 36),
          const SizedBox(height: 8),
          Text(
            'No snapshots for this view.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust filters or run the cron / web "Rebuild all" to compute snapshots for this period.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
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

String _formatYmd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: SiChrome.inputDecoration(
          context,
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
        ),
        child: Text(
          _formatYmd(value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _SmStatusBadge extends StatelessWidget {
  const _SmStatusBadge({
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;

  factory _SmStatusBadge.fromStatus(SmartMonitoringStatus status) {
    return _SmStatusBadge(
      label: status.label,
      color: SmartMonitoringPalette.statusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SmTrendBadge extends StatelessWidget {
  const _SmTrendBadge(this.trend, {this.previous});
  final SmartMonitoringTrend trend;
  final double? previous;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (trend) {
      case SmartMonitoringTrend.up:
        icon = Icons.trending_up_rounded;
        color = SmartMonitoringPalette.good;
        break;
      case SmartMonitoringTrend.down:
        icon = Icons.trending_down_rounded;
        color = SmartMonitoringPalette.critical;
        break;
      case SmartMonitoringTrend.stable:
        icon = Icons.trending_flat_rounded;
        color = AppColors.textSecondary;
        break;
    }
    final tooltip = previous != null
        ? 'Trend ${trend.label.toLowerCase()} vs previous (${previous!.toStringAsFixed(1)})'
        : 'Trend ${trend.label.toLowerCase()}';
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              trend.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmRiskBadge extends StatelessWidget {
  const _SmRiskBadge(this.risk);
  final SmartMonitoringRisk risk;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (risk) {
      case SmartMonitoringRisk.critical:
        color = SmartMonitoringPalette.critical;
        break;
      case SmartMonitoringRisk.warning:
        color = SmartMonitoringPalette.warning;
        break;
      case SmartMonitoringRisk.normal:
        color = AppColors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        'Risk: ${risk.label}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SmStatChip extends StatelessWidget {
  const _SmStatChip({
    required this.icon,
    required this.label,
    required this.tooltip,
  });
  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.textSecondary.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
