import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learining_portal/network/data_models/class_summary_flashcards/class_summary_flashcards_models.dart';
import 'package:learining_portal/network/domain/class_summary_flashcards_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

const String _kGwrLogoStudy =
    'https://gcsewithrosi.co.uk/wp-content/uploads/2024/09/cropped-DALL%C2%B7E-2024-09-25-23.04.37-A-simple-and-child-friendly-logo-for-GCSE-WITH-ROSI_-featuring-a-light-bulb-on-top-of-an-open-book.-The-title-GCSE-WITH-ROSI-should-be-prominently-1.jpg';

class ClassSummaryFlashcardStudyScreen extends StatefulWidget {
  const ClassSummaryFlashcardStudyScreen({
    super.key,
    required this.setId,
    required this.studentId,
  });

  final int setId;
  final int studentId;

  @override
  State<ClassSummaryFlashcardStudyScreen> createState() =>
      _ClassSummaryFlashcardStudyScreenState();
}

class _ClassSummaryFlashcardStudyScreenState extends State<ClassSummaryFlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  ClassSummaryFlashcardSet? _set;
  int _index = 0;
  bool _finishing = false;

  late AnimationController _flipCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _set = null;
      _index = 0;
    });
    _flipCtrl.value = 0;
    try {
      final payload = await ClassSummaryFlashcardsRepository.getSetDetailForStudent(
        studentId: widget.studentId,
        setId: widget.setId,
      );
      if (!payload.success || payload.set == null) {
        _error = payload.error ?? 'Failed to load flashcards.';
        _set = null;
      } else {
        _set = payload.set;
      }
    } catch (e) {
      _error = e.toString();
      _set = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _resetFlip() {
    if (_flipCtrl.value != 0) {
      _flipCtrl.reset();
    }
  }

  void _prev() {
    if (_set == null || _set!.cards.isEmpty) return;
    setState(() {
      _index = (_index - 1).clamp(0, _set!.cards.length - 1);
      _resetFlip();
    });
  }

  void _next() {
    if (_set == null || _set!.cards.isEmpty) return;
    setState(() {
      _index = (_index + 1).clamp(0, _set!.cards.length - 1);
      _resetFlip();
    });
  }

  Future<void> _finishDeck() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final r = await ClassSummaryFlashcardsRepository.completeDeckForStudent(
        studentId: widget.studentId,
        setId: widget.setId,
      );
      if (!mounted) return;
      if (r['success'] != true) {
        final msg = r['error']?.toString() ?? 'Could not save progress.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save progress.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _set?.displayTopic ?? 'Flashcards';
    final total = _set?.cards.length ?? 0;

    return SiThemedPageScaffold(
      title: 'Study deck',
      subtitle: topic,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _set == null
              ? SiEmptyState(
                  icon: Icons.style_outlined,
                  title: 'Unable to load',
                  message: _error,
                )
              : total == 0
                  ? const SiEmptyState(
                      icon: Icons.style_outlined,
                      title: 'No cards',
                      message: 'This deck has no cards.',
                    )
                  : _buildStudy(context, _set!, total),
    );
  }

  Widget _buildStudy(BuildContext context, ClassSummaryFlashcardSet deck, int total) {
    final card = deck.cards[_index];
    final isLast = _index >= total - 1;
    final progress = ((_index + 1) / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEEF2F7),
            Color(0xFFF7F9FC),
            Colors.white,
          ],
          stops: [0, 0.35, 1],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressPanel(
              index: _index,
              total: total,
              progress: progress,
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AspectRatio(
                  aspectRatio: 1.05,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Focus(
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) return KeyEventResult.ignored;
                          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                            _prev();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                            _next();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (_flipCtrl.isAnimating) return;
                            if (_flipCtrl.value == 0) {
                              _flipCtrl.forward();
                            } else {
                              _flipCtrl.reverse();
                            }
                          },
                          child: AnimatedBuilder(
                            animation: _flipCtrl,
                            builder: (context, _) {
                              final angle = _flipCtrl.value * math.pi;
                              final showBack = angle >= math.pi / 2;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: showBack
                                    ? Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(math.pi),
                                        child: _CardFace(
                                          label: 'Answer',
                                          text: card.back,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF0d5c55),
                                              Color(0xFF0f766e),
                                              Color(0xFF14b8a6),
                                            ],
                                          ),
                                          hint: 'Tap to see question',
                                          maxSide: c.maxWidth,
                                        ),
                                      )
                                    : _CardFace(
                                        label: 'Question',
                                        text: card.front,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF1a365d),
                                            Color(0xFF2c5282),
                                            Color(0xFF3182ce),
                                          ],
                                        ),
                                        hint: 'Tap to reveal answer',
                                        maxSide: c.maxWidth,
                                      ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the card to flip · Arrow keys when focused',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _index == 0 ? null : _prev,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _index >= total - 1 ? null : _next,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF3c8dbc),
                    ),
                  ),
                ),
              ],
            ),
            if (isLast) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _finishing ? null : _finishDeck,
                icon: _finishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_finishing ? 'Saving…' : 'Finish deck'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF27ae60),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.index,
    required this.total,
    required this.progress,
  });

  final int index;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${index + 1} / $total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'CARD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08 * 12,
                    color: Colors.blueGrey.shade300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFF3c8dbc),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index ? const Color(0xFF3c8dbc) : const Color(0xFFCBD5E1),
                      boxShadow: i == index
                          ? [BoxShadow(color: const Color(0xFF3c8dbc).withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 3)]
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.label,
    required this.text,
    required this.gradient,
    required this.hint,
    required this.maxSide,
  });

  final String label;
  final String text;
  final Gradient gradient;
  final String hint;
  final double maxSide;

  @override
  Widget build(BuildContext context) {
    final logo = 34.0.clamp(24.0, maxSide * 0.22);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: Opacity(
                opacity: 0.92,
                child: Image.network(_kGwrLogoStudy, height: logo, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Opacity(
                opacity: 0.92,
                child: Image.network(_kGwrLogoStudy, height: logo, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            Positioned(
              bottom: 52,
              left: 8,
              child: Opacity(
                opacity: 0.92,
                child: Image.network(_kGwrLogoStudy, height: logo, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            Positioned(
              bottom: 52,
              right: 8,
              child: Opacity(
                opacity: 0.92,
                child: Image.network(_kGwrLogoStudy, height: logo, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          text.trim().isEmpty ? '—' : text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (maxSide * 0.045).clamp(16, 22),
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
