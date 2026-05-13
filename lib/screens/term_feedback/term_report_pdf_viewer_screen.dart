// lib/screens/term_feedback/term_report_pdf_viewer_screen.dart
//
// In-app PDF reader for the parent's published term-report PDFs.
//
// Mirrors the web's "/user/termreport/ → modal iframe" UX: the PDFs are
// downloaded transiently to the device's temp directory, rendered with
// `flutter_pdfview`, and never offered to the system downloader unless the
// admin explicitly enabled `download_allowed`.
//
// Supports both single-report viewing and multi-select carousel:
//   • One report → opens directly on its page.
//   • N reports  → PageView with swipe-between-reports, plus a page indicator
//                  + prev/next buttons.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:learining_portal/network/data_models/term_feedback/child_term_report_models.dart';
import 'package:learining_portal/network/domain/term_feedback_repository.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';

class TermReportPdfViewerScreen extends StatefulWidget {
  const TermReportPdfViewerScreen({
    super.key,
    required this.appParentId,
    required this.studentId,
    required this.reports,
    this.initialIndex = 0,
    this.childDisplayName,
  });

  /// Logged-in guardian's `app_parents.id`.
  final int appParentId;

  /// The active child whose reports are being viewed.
  final int studentId;

  /// One or more published reports to flip through.
  final List<ChildPublishedTermReport> reports;

  /// Index in [reports] to start on.
  final int initialIndex;

  /// Optional display name for the AppBar subtitle (e.g. "Liam Carter").
  final String? childDisplayName;

  @override
  State<TermReportPdfViewerScreen> createState() =>
      _TermReportPdfViewerScreenState();
}

class _TermReportPdfViewerScreenState extends State<TermReportPdfViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final start = widget.initialIndex.clamp(0, widget.reports.length - 1);
    _currentIndex = start;
    _pageController = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_currentIndex + delta).clamp(0, widget.reports.length - 1);
    if (next == _currentIndex) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.reports.length;
    final isMulti = total > 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMulti
                  ? '${widget.reports[_currentIndex].termLabel} · ${_currentIndex + 1}/$total'
                  : widget.reports[_currentIndex].termLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if ((widget.childDisplayName ?? '').isNotEmpty)
              Text(
                widget.childDisplayName!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (isMulti) _ReportTabsStrip(
            reports: widget.reports,
            currentIndex: _currentIndex,
            onTap: (i) {
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.reports.length,
              onPageChanged: (i) {
                if (!mounted) return;
                setState(() => _currentIndex = i);
              },
              itemBuilder: (context, i) {
                return _SinglePdfPage(
                  key: ValueKey('pdf-${widget.reports[i].id}'),
                  appParentId: widget.appParentId,
                  studentId: widget.studentId,
                  report: widget.reports[i],
                );
              },
            ),
          ),
          if (isMulti)
            _CarouselFooter(
              current: _currentIndex,
              total: total,
              onPrev: _currentIndex > 0 ? () => _go(-1) : null,
              onNext:
                  _currentIndex < total - 1 ? () => _go(1) : null,
            ),
        ],
      ),
    );
  }
}

// ─── Top tabs strip (multi-select mode) ─────────────────────────────────────

class _ReportTabsStrip extends StatelessWidget {
  const _ReportTabsStrip({
    required this.reports,
    required this.currentIndex,
    required this.onTap,
  });

  final List<ChildPublishedTermReport> reports;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(reports.length, (i) {
            final selected = i == currentIndex;
            final r = reports[i];
            final color = termColor(r.termNumber);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : Colors.white.withOpacity(0.0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        r.termLabel,
                        style: TextStyle(
                          color: selected ? color : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Bottom footer (prev/next + index dots) ─────────────────────────────────

class _CarouselFooter extends StatelessWidget {
  const _CarouselFooter({
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFF111827),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _FooterIconButton(
              icon: Icons.chevron_left_rounded,
              label: 'Previous',
              onTap: onPrev,
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(total, (i) {
                final selected = i == current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const Spacer(),
            _FooterIconButton(
              icon: Icons.chevron_right_rounded,
              label: 'Next',
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.white.withOpacity(disabled ? 0.05 : 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == Icons.chevron_left_rounded) ...[
                Icon(
                  icon,
                  color: disabled ? Colors.white38 : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              if (icon == Icons.chevron_right_rounded) ...[
                const SizedBox(width: 2),
                Icon(
                  icon,
                  color: disabled ? Colors.white38 : Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Single PDF page (loads + renders one report) ───────────────────────────

class _SinglePdfPage extends StatefulWidget {
  const _SinglePdfPage({
    super.key,
    required this.appParentId,
    required this.studentId,
    required this.report,
  });

  final int appParentId;
  final int studentId;
  final ChildPublishedTermReport report;

  @override
  State<_SinglePdfPage> createState() => _SinglePdfPageState();
}

class _SinglePdfPageState extends State<_SinglePdfPage>
    with AutomaticKeepAliveClientMixin {
  String? _localPath;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await TermFeedbackRepository.downloadPublishedReportPdf(
        appParentId: widget.appParentId,
        studentId: widget.studentId,
        reportId: widget.report.id,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _localPath = path;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return _CenteredBlock(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 14),
            Text(
              'Loading ${widget.report.termLabel} report…',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _CenteredBlock(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final path = _localPath;
    if (path == null || !File(path).existsSync()) {
      return _CenteredBlock(
        child: Text(
          'Report not available.',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return PDFView(
      filePath: path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: false,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = err.toString();
        });
      },
      onPageError: (page, err) {
        if (!mounted) return;
        setState(() {
          _error = 'Error on page $page: $err';
        });
      },
    );
  }
}

class _CenteredBlock extends StatelessWidget {
  const _CenteredBlock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F2937),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ─── Term colour palette (shared with the list screen) ─────────────────────

/// Stable colour per term number, matching the web's term-card palette so
/// parents see the same colour-coding across platforms.
Color termColor(int termNumber) {
  switch (termNumber) {
    case 1:
      return const Color(0xFF1E4FB5);
    case 2:
      return const Color(0xFF27AE60);
    case 3:
      return const Color(0xFFE84545);
    default:
      return AppColors.primaryBlue;
  }
}
