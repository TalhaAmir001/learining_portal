import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learining_portal/network/data_models/class_summary/class_summary_models.dart';
import 'package:learining_portal/network/domain/class_summary_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/class_summary_formatters.dart';
import 'package:learining_portal/utils/class_summary_slide_parser.dart';

/// Same branding asset as [Portal 2 new]/application/views/user/classsummary/view.php.
const String _kGwrLogoUrl =
    'https://gcsewithrosi.co.uk/wp-content/uploads/2024/09/cropped-DALL%C2%B7E-2024-09-25-23.04.37-A-simple-and-child-friendly-logo-for-GCSE-WITH-ROSI_-featuring-a-light-bulb-on-top-of-an-open-book.-The-title-GCSE-WITH-ROSI-should-be-prominently-1.jpg';

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
  List<ClassSummarySlide> _slides = const [];
  int _slideIndex = 0;
  bool _audioOn = true;
  double _speechRate = 0.9;
  bool _immersiveUi = false;
  FlutterTts? _tts;
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    final t = FlutterTts();
    await t.setLanguage('en-GB');
    if (!mounted) return;
    setState(() {
      _tts = t;
      _ttsReady = true;
    });
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
        _slides = const [];
      } else {
        _summary = payload.summary;
        _slides = buildClassSummarySlides(_summary!.htmlContent);
        _slideIndex = 0;
      }
    } catch (e) {
      _error = e.toString();
      _summary = null;
      _slides = const [];
    }
    if (mounted) setState(() => _loading = false);
    if (mounted && _slides.isNotEmpty && _audioOn) {
      unawaited(_speakCurrentSlide(delay: const Duration(milliseconds: 400)));
    }
  }

  Future<void> _speakCurrentSlide({Duration delay = Duration.zero}) async {
    if (!_ttsReady || _tts == null || !_audioOn || _slides.isEmpty) return;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!mounted) return;
    final text = _slides[_slideIndex.clamp(0, _slides.length - 1)].narration;
    if (text == null || text.trim().isEmpty) return;
    await _tts!.stop();
    await _tts!.setSpeechRate(_speechRate);
    await _tts!.speak(text);
  }

  Future<void> _stopSpeech() async {
    if (_tts != null) await _tts!.stop();
  }

  void _showSlide(int next) {
    if (_slides.isEmpty) return;
    final n = (next + _slides.length) % _slides.length;
    if (n == _slideIndex) return;
    unawaited(_stopSpeech());
    setState(() => _slideIndex = n);
    if (_audioOn) unawaited(_speakCurrentSlide(delay: const Duration(milliseconds: 280)));
  }

  Future<void> _toggleImmersive() async {
    final next = !_immersiveUi;
    setState(() => _immersiveUi = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    unawaited(_stopSpeech());
    _tts = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _headerTitle() {
    final s = _summary;
    if (s == null) return 'Class summary';
    final t = s.title.trim();
    if (t.isNotEmpty) return t;
    return formatClassSummaryListDate(s.classDate);
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final total = _slides.length;
    final boxTitle = s == null
        ? 'Class summary'
        : [
            if (s.title.trim().isNotEmpty) s.title.trim(),
            formatClassSummaryListDate(s.classDate),
          ].join(' – ');

    return SiThemedPageScaffold(
      title: 'Class Summary',
      subtitle: _headerTitle(),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : s == null
              ? SiEmptyState(
                  icon: Icons.article_outlined,
                  title: 'Unable to load',
                  message: _error,
                )
              : total == 0
                  ? SiEmptyState(
                      icon: Icons.article_outlined,
                      title: 'Empty summary',
                      message: _error ?? 'No slide content.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Text(
                            boxTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Focus(
                            autofocus: true,
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) return KeyEventResult.ignored;
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                if (_slideIndex > 0) _showSlide(_slideIndex - 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                if (_slideIndex < total - 1) _showSlide(_slideIndex + 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.space) {
                                setState(() => _audioOn = !_audioOn);
                                if (_audioOn) {
                                  unawaited(_speakCurrentSlide());
                                } else {
                                  unawaited(_stopSpeech());
                                }
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: ColoredBox(
                                      color: Colors.white,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: DecoratedBox(
                                                    decoration: const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                        colors: [
                                                          Color(0xFF1a1a2e),
                                                          Color(0xFF16213e),
                                                        ],
                                                      ),
                                                    ),
                                                    child: SingleChildScrollView(
                                                      padding: const EdgeInsets.fromLTRB(
                                                        16,
                                                        56,
                                                        16,
                                                        20,
                                                      ),
                                                      child: Html(
                                                        data: _slides[_slideIndex].outerHtml,
                                                        style: {
                                                          'body': Style(
                                                            margin: Margins.zero,
                                                            padding: HtmlPaddings.zero,
                                                            color: Colors.white,
                                                            fontSize: FontSize(15),
                                                            lineHeight: const LineHeight(1.45),
                                                          ),
                                                          'p': Style(color: Colors.white),
                                                          'li': Style(color: Colors.white),
                                                          'h1': Style(color: Colors.white),
                                                          'h2': Style(color: Colors.white),
                                                          'h3': Style(color: Colors.white),
                                                          'span': Style(color: Colors.white),
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 10,
                                                  left: 0,
                                                  right: 0,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Image.network(
                                                        _kGwrLogoUrl,
                                                        height: 36,
                                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'GCSE WITH ROSI',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 14,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Row(
                                                    children: [
                                                      _RoundIcon(
                                                        icon: _immersiveUi ? Icons.close_fullscreen : Icons.fullscreen,
                                                        onTap: _toggleImmersive,
                                                        tooltip: _immersiveUi ? 'Exit fullscreen' : 'Fullscreen',
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _RoundIcon(
                                                        icon: _audioOn ? Icons.volume_up : Icons.volume_off,
                                                        onTap: () {
                                                          setState(() => _audioOn = !_audioOn);
                                                          if (_audioOn) {
                                                            unawaited(_speakCurrentSlide());
                                                          } else {
                                                            unawaited(_stopSpeech());
                                                          }
                                                        },
                                                        tooltip: _audioOn ? 'Mute narration' : 'Narration on',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _SlideControlsBar(
                                            slideIndex: _slideIndex,
                                            total: total,
                                            speechRate: _speechRate,
                                            onPrev: _slideIndex > 0 ? () => _showSlide(_slideIndex - 1) : null,
                                            onNext: _slideIndex < total - 1 ? () => _showSlide(_slideIndex + 1) : null,
                                            onRateChanged: (v) {
                                              setState(() => _speechRate = v);
                                              if (_audioOn) unawaited(_speakCurrentSlide());
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            'Arrow keys: previous / next slide · Space: toggle narration',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SlideControlsBar extends StatelessWidget {
  const _SlideControlsBar({
    required this.slideIndex,
    required this.total,
    required this.speechRate,
    required this.onPrev,
    required this.onNext,
    required this.onRateChanged,
  });

  final int slideIndex;
  final int total;
  final double speechRate;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<double> onRateChanged;

  static const _rates = [0.5, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade200,
          ],
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
          ),
          Text(
            '${slideIndex + 1} / $total',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Speed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              DropdownButton<double>(
                value: _rates.contains(speechRate) ? speechRate : 0.9,
                items: [
                  for (final r in _rates)
                    DropdownMenuItem(value: r, child: Text('${r}×')),
                ],
                onChanged: (v) {
                  if (v != null) onRateChanged(v);
                },
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }
}
