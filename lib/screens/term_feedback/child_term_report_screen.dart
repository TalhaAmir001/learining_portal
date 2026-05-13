// lib/screens/term_feedback/child_term_report_screen.dart
//
// Parent-facing "Term Report" screen.
//
// Lists the school's *published* term-report PDFs (Term 1 / 2 / 3) for the
// guardian's currently-active child. Read-only; the parent can tap a card to
// view a single report or long-press to multi-select and view several in a
// swipable carousel.
//
// Behaviour:
//   • Listens to AuthProvider so switching the active child auto-reloads.
//   • Pull-to-refresh re-fetches from the server.
//   • Empty / error / no-active-child states all render in-page; no toasts.

import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/data_models/term_feedback/child_term_report_models.dart';
import 'package:learining_portal/network/domain/term_feedback_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/parent_children/my_children_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/screens/term_feedback/term_report_pdf_viewer_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class ChildTermReportScreen extends StatefulWidget {
  const ChildTermReportScreen({super.key});

  @override
  State<ChildTermReportScreen> createState() => _ChildTermReportScreenState();
}

class _ChildTermReportScreenState extends State<ChildTermReportScreen> {
  bool _isLoading = false;
  String? _error;
  ChildTermReportHeader? _header;
  List<ChildPublishedTermReport> _reports = const [];

  /// Multi-select state for the report list. Stored as a Set of report ids so
  /// re-ordering / re-fetching doesn't lose the selection.
  bool _selectMode = false;
  final Set<int> _selectedReportIds = <int>{};

  /// `(appParentId, studentId)` last fetched for. Triggers a re-fetch when
  /// either changes (e.g. parent switches active child while screen open).
  ({int parentId, int studentId})? _lastKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeFetch();
  }

  void _maybeFetch() {
    final auth = context.read<AuthProvider>();
    final parentId = _resolveParentId(auth);
    final studentId = auth.effectiveChildId;
    if (parentId == null || studentId == null) return;
    final key = (parentId: parentId, studentId: studentId);
    if (_lastKey == key) return;
    _lastKey = key;
    // Active child swapped — drop any selection from the previous child.
    _selectMode = false;
    _selectedReportIds.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  int? _resolveParentId(AuthProvider auth) {
    if (auth.userType != UserType.guardian) return null;
    final raw = auth.currentUser?.additionalData?['app_parent_id'] ??
        auth.currentUser?.additionalData?['id'] ??
        auth.currentUser?.id;
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    final n = int.tryParse(raw.toString());
    return (n != null && n > 0) ? n : null;
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthProvider>();
    final parentId = _resolveParentId(auth);
    final studentId = auth.effectiveChildId;
    if (parentId == null || studentId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final payload = await TermFeedbackRepository.getChildPublishedReports(
      appParentId: parentId,
      studentId: studentId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (payload.success) {
        _header = payload.child ?? _header;
        _reports = payload.reports;
        _error = null;
        // Drop any selected ids that disappeared from the latest list.
        _selectedReportIds.retainAll(_reports.map((r) => r.id).toSet());
        if (_selectedReportIds.isEmpty) {
          _selectMode = false;
        }
      } else {
        _reports = const [];
        _error = payload.error ?? 'Failed to load term reports.';
      }
    });
  }

  Future<void> _refresh() => _fetch();

  // ── PDF selection helpers ───────────────────────────────────────────────

  void _toggleSelected(int reportId) {
    setState(() {
      if (_selectedReportIds.contains(reportId)) {
        _selectedReportIds.remove(reportId);
      } else {
        _selectedReportIds.add(reportId);
      }
      if (_selectedReportIds.isEmpty) {
        _selectMode = false;
      }
    });
  }

  void _enterSelectMode(int firstSelectedId) {
    setState(() {
      _selectMode = true;
      _selectedReportIds.add(firstSelectedId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedReportIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectMode = true;
      _selectedReportIds
        ..clear()
        ..addAll(_reports.map((r) => r.id));
    });
  }

  void _openSelected() {
    final auth = context.read<AuthProvider>();
    final parentId = _resolveParentId(auth);
    final studentId = auth.effectiveChildId;
    if (parentId == null || studentId == null) return;

    final selected = _reports
        .where((r) => _selectedReportIds.contains(r.id))
        .toList(growable: false);
    if (selected.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermReportPdfViewerScreen(
          appParentId: parentId,
          studentId: studentId,
          reports: selected,
          childDisplayName:
              _header?.fullName ?? auth.selectedChild?.fullName,
        ),
      ),
    );
  }

  void _openSingle(ChildPublishedTermReport report) {
    final auth = context.read<AuthProvider>();
    final parentId = _resolveParentId(auth);
    final studentId = auth.effectiveChildId;
    if (parentId == null || studentId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermReportPdfViewerScreen(
          appParentId: parentId,
          studentId: studentId,
          reports: [report],
          childDisplayName:
              _header?.fullName ?? auth.selectedChild?.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Re-evaluate fetch key on auth changes (e.g. selected child switch).
        _maybeFetch();

        final isGuardian = auth.userType == UserType.guardian;
        final hasChildren = auth.linkedChildren.isNotEmpty;
        final activeChildId = auth.effectiveChildId;
        final showSelectionBar = _selectMode && _selectedReportIds.isNotEmpty;

        return SiThemedPageScaffold(
          title: 'Term Report',
          subtitle: isGuardian
              ? 'Your child\'s published term-report PDFs'
              : 'Available to guardian accounts',
          child: !isGuardian
              ? const _NotGuardianBlock()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: RefreshIndicator(
                        color: AppColors.primaryBlue,
                        onRefresh: _refresh,
                        child: _buildBody(
                          auth: auth,
                          hasChildren: hasChildren,
                          activeChildId: activeChildId,
                        ),
                      ),
                    ),
                    if (showSelectionBar)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _SelectionActionBar(
                          selectedCount: _selectedReportIds.length,
                          totalCount: _reports.length,
                          onCancel: _exitSelectMode,
                          onSelectAll: _selectAll,
                          onOpenSelected: _openSelected,
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBody({
    required AuthProvider auth,
    required bool hasChildren,
    required int? activeChildId,
  }) {
    if (!hasChildren && !auth.isLoadingLinkedChildren) {
      return _ScrollableBlock(child: _NoChildrenBlock());
    }
    if (activeChildId == null) {
      return _ScrollableBlock(
        child: _PickActiveChildBlock(linked: auth.linkedChildren),
      );
    }
    if (_isLoading && _reports.isEmpty && _error == null) {
      return _ScrollableBlock(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 96),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null && _reports.isEmpty) {
      return _ScrollableBlock(
        child: _ErrorBlock(message: _error!, onRetry: _fetch),
      );
    }
    if (_reports.isEmpty) {
      return _ScrollableBlock(
        child: _EmptyReportsBlock(
          header: _header,
          child: _selectedChildHint(auth),
        ),
      );
    }

    final header = _header;
    final bottomPadding =
        (_selectMode && _selectedReportIds.isNotEmpty) ? 96.0 : 24.0;

    final children = <Widget>[
      _ChildHeaderCard(
        header: header,
        fallback: _selectedChildHint(auth),
      ),
      const SizedBox(height: 18),
      _PdfSectionHeader(
        count: _reports.length,
        inSelectionMode: _selectMode,
        selectedCount: _selectedReportIds.length,
        onToggleSelectionMode: () {
          if (_selectMode) {
            _exitSelectMode();
          } else {
            setState(() {
              _selectMode = true;
            });
          }
        },
      ),
      const SizedBox(height: 10),
      ..._reports.map((r) {
        final selected = _selectedReportIds.contains(r.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PdfReportCard(
            report: r,
            selected: selected,
            inSelectionMode: _selectMode,
            onTap: () {
              if (_selectMode) {
                _toggleSelected(r.id);
              } else {
                _openSingle(r);
              }
            },
            onLongPress: () {
              if (_selectMode) {
                _toggleSelected(r.id);
              } else {
                _enterSelectMode(r.id);
              }
            },
          ),
        );
      }),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      children: children,
    );
  }

  /// Fallback display fields when the server hasn't returned a header yet
  /// (e.g. loading state) — uses the parent's local ParentChild snapshot.
  ParentChild? _selectedChildHint(AuthProvider auth) => auth.selectedChild;
}

// ─── PDF report section: header + card + skeleton + selection bar ───────────

class _PdfSectionHeader extends StatelessWidget {
  const _PdfSectionHeader({
    required this.count,
    required this.inSelectionMode,
    required this.selectedCount,
    required this.onToggleSelectionMode,
  });

  final int count;
  final bool inSelectionMode;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Published Reports',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                inSelectionMode
                    ? '$selectedCount of $count selected'
                    : '$count term ${count == 1 ? 'report' : 'reports'} ready to read',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (count > 1)
          TextButton.icon(
            onPressed: onToggleSelectionMode,
            icon: Icon(
              inSelectionMode
                  ? Icons.close_rounded
                  : Icons.checklist_rounded,
              size: 18,
              color: AppColors.primaryBlue,
            ),
            label: Text(
              inSelectionMode ? 'Done' : 'Select',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

class _PdfReportCard extends StatelessWidget {
  const _PdfReportCard({
    required this.report,
    required this.selected,
    required this.inSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final ChildPublishedTermReport report;
  final bool selected;
  final bool inSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = termColor(report.termNumber);
    final tileBorderColor = selected ? color : AppColors.textSecondary.withOpacity(0.12);
    final tileBorderWidth = selected ? 2.0 : 1.0;
    return Material(
      color: selected ? color.withOpacity(0.06) : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tileBorderColor, width: tileBorderWidth),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${report.termLabel} Report',
                              style: TextStyle(
                                color: color,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PublishedPill(color: color),
                          ],
                        ),
                        if (report.periodStartMonth.isNotEmpty ||
                            report.periodEndMonth.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatPeriod(
                              report.periodStartMonth,
                              report.periodEndMonth,
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (report.publishedAt.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Published ${_formatPublishedAt(report.publishedAt)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                  child: Center(
                    child: inSelectionMode
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: selected ? color : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? color
                                    : AppColors.textSecondary.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishedPill extends StatelessWidget {
  const _PublishedPill({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Published',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onCancel,
    required this.onSelectAll,
    required this.onOpenSelected,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onOpenSelected;

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedCount >= totalCount && totalCount > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          elevation: 8,
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(16),
          shadowColor: AppColors.primaryBlue.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$selectedCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'reports selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!allSelected)
                  TextButton(
                    onPressed: onSelectAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text(
                      'All',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
                FilledButton.icon(
                  onPressed: selectedCount > 0 ? onOpenSelected : null,
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Converts "YYYY-MM-DD HH:MM:SS" → "12 Sep 2024". Best-effort.
String _formatPublishedAt(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  try {
    final dt = DateTime.parse(trimmed.replaceFirst(' ', 'T'));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day.toString().padLeft(2, '0')} '
        '${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return trimmed;
  }
}

// ─── Header card ─────────────────────────────────────────────────────────────

class _ChildHeaderCard extends StatelessWidget {
  const _ChildHeaderCard({required this.header, required this.fallback});

  final ChildTermReportHeader? header;
  final ParentChild? fallback;

  @override
  Widget build(BuildContext context) {
    final name = header?.fullName ??
        fallback?.fullName ??
        'Active child';
    final admission = header?.admissionNo ?? fallback?.admissionNo ?? '';
    final classLabel = header?.classLabel ?? fallback?.classLabel ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (admission.isNotEmpty) 'Adm: $admission',
                    if (classLabel.isNotEmpty) classLabel,
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error / no-child states ────────────────────────────────────────

class _ScrollableBlock extends StatelessWidget {
  const _ScrollableBlock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [child],
    );
  }
}

class _NoChildrenBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SiEmptyState(
          icon: Icons.family_restroom_rounded,
          title: 'No children linked yet',
          message: 'Link your child with the 6-character code from school '
              'to see their term reports here.',
        ),
        const SizedBox(height: 4),
        _CtaButton(
          label: 'Go to My Children',
          icon: Icons.arrow_forward_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyChildrenScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _PickActiveChildBlock extends StatelessWidget {
  const _PickActiveChildBlock({required this.linked});
  final List<ParentChild> linked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SiEmptyState(
          icon: Icons.swap_horiz_rounded,
          title: 'Pick an active child',
          message: linked.length >= 2
              ? 'You have ${linked.length} linked children. Pick one as the '
                  'active child to view their term reports.'
              : 'Pick the active child from the dashboard to view their '
                  'term reports.',
        ),
        const SizedBox(height: 4),
        _CtaButton(
          label: 'Open My Children',
          icon: Icons.arrow_forward_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyChildrenScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _NotGuardianBlock extends StatelessWidget {
  const _NotGuardianBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: SiEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Guardians only',
        message: 'Sign in as a parent to view your child\'s term reports.',
      ),
    );
  }
}

class _EmptyReportsBlock extends StatelessWidget {
  const _EmptyReportsBlock({required this.header, required this.child});
  final ChildTermReportHeader? header;
  final ParentChild? child;

  @override
  Widget build(BuildContext context) {
    final name = header?.fullName ?? child?.fullName ?? 'your child';
    return Column(
      children: [
        if (header != null || child != null)
          _ChildHeaderCard(header: header, fallback: child),
        const SizedBox(height: 18),
        SiEmptyState(
          icon: Icons.picture_as_pdf_outlined,
          title: 'No reports yet',
          message: 'The school hasn\'t published any term reports for $name '
              'this session. Check back later — pull down to refresh.',
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade700,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const List<String> _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2024-09" → "Sep 2024". Falls back to the raw string when malformed.
String _formatMonth(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  final year = parts[0];
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return ym;
  return '${_monthLabels[m - 1]} $year';
}

/// "2024-09" + "2024-12" → "Sep – Dec 2024" (compact, same-year). Different
/// years → "Sep 2024 – Mar 2025". Single month → just "Sep 2024".
String _formatPeriod(String startYm, String endYm) {
  if (startYm.isEmpty && endYm.isEmpty) return '—';
  if (startYm.isEmpty) return _formatMonth(endYm);
  if (endYm.isEmpty) return _formatMonth(startYm);
  if (startYm == endYm) return _formatMonth(startYm);

  final s = startYm.split('-');
  final e = endYm.split('-');
  if (s.length == 2 && e.length == 2 && s[0] == e[0]) {
    final sm = int.tryParse(s[1]);
    final em = int.tryParse(e[1]);
    if (sm != null && em != null && sm >= 1 && em <= 12) {
      return '${_monthLabels[sm - 1]} – ${_monthLabels[em - 1]} ${s[0]}';
    }
  }
  return '${_formatMonth(startYm)} – ${_formatMonth(endYm)}';
}
