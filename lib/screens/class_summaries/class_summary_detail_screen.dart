import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:learining_portal/network/data_models/class_summary/class_summary_models.dart';
import 'package:learining_portal/network/domain/class_summary_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

class ClassSummaryDetailScreen extends StatefulWidget {
  const ClassSummaryDetailScreen({
    super.key,
    required this.summaryId,
    required this.studentId,
  });

  final int summaryId;
  final int studentId;

  @override
  State<ClassSummaryDetailScreen> createState() => _ClassSummaryDetailScreenState();
}

class _ClassSummaryDetailScreenState extends State<ClassSummaryDetailScreen> {
  bool _loading = true;
  String? _error;
  ClassSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await ClassSummaryRepository.getDetailForStudent(
        studentId: widget.studentId,
        summaryId: widget.summaryId,
      );
      if (!payload.success || payload.summary == null) {
        _error = payload.error ?? 'Failed to load class summary.';
        _summary = null;
      } else {
        _summary = payload.summary;
      }
    } catch (e) {
      _error = e.toString();
      _summary = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _summary?.displayTitle ?? 'Class summary';
    final subtitleParts = <String>[];
    final d = _summary?.classDate.trim() ?? '';
    if (d.isNotEmpty) subtitleParts.add(d);
    final clsSec = [
      _summary?.className.trim() ?? '',
      _summary?.sectionName.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' • ');
    if (clsSec.isNotEmpty) subtitleParts.add(clsSec);

    return SiThemedPageScaffold(
      title: title,
      subtitle: subtitleParts.isEmpty ? 'Summary detail' : subtitleParts.join(' • '),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _summary == null
              ? SiEmptyState(
                  icon: Icons.article_outlined,
                  title: 'Unable to load',
                  message: _error,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if ((_summary?.title.trim() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _summary!.title.trim(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Html(
                      data: _summary!.htmlContent,
                      style: {
                        'body': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(15),
                          lineHeight: const LineHeight(1.35),
                        ),
                      },
                    ),
                  ],
                ),
    );
  }
}

