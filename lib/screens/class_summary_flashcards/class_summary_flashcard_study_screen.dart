import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/class_summary_flashcards/class_summary_flashcards_models.dart';
import 'package:learining_portal/network/domain/class_summary_flashcards_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

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

class _ClassSummaryFlashcardStudyScreenState
    extends State<ClassSummaryFlashcardStudyScreen> {
  bool _loading = true;
  String? _error;
  ClassSummaryFlashcardSet? _set;
  int _index = 0;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _set = null;
      _index = 0;
      _showBack = false;
    });
    try {
      final payload =
          await ClassSummaryFlashcardsRepository.getSetDetailForStudent(
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

  void _prev() {
    if (_set == null || _set!.cards.isEmpty) return;
    setState(() {
      _index = (_index - 1).clamp(0, _set!.cards.length - 1);
      _showBack = false;
    });
  }

  void _next() {
    if (_set == null || _set!.cards.isEmpty) return;
    setState(() {
      _index = (_index + 1).clamp(0, _set!.cards.length - 1);
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topic = _set?.displayTopic ?? 'Flashcards';
    final subtitleParts = <String>[];
    final d = _set?.classDate.trim() ?? '';
    if (d.isNotEmpty) subtitleParts.add(d);
    final clsSec = [
      _set?.className.trim() ?? '',
      _set?.sectionName.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' • ');
    if (clsSec.isNotEmpty) subtitleParts.add(clsSec);

    return SiThemedPageScaffold(
      title: 'Flashcards',
      subtitle: subtitleParts.isEmpty ? topic : subtitleParts.join(' • '),
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
              : _set!.cards.isEmpty
                  ? const SiEmptyState(
                      icon: Icons.style_outlined,
                      title: 'No cards',
                      message: 'This deck has no cards.',
                    )
                  : _buildStudy(context, _set!),
    );
  }

  Widget _buildStudy(BuildContext context, ClassSummaryFlashcardSet deck) {
    final card = deck.cards[_index];
    final total = deck.cards.length;
    final showing = _showBack ? 'Answer' : 'Question';
    final text = (_showBack ? card.back : card.front).trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            deck.displayTopic,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Card ${_index + 1} of $total • $showing',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _showBack = !_showBack),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    text.isEmpty ? 'Tap to reveal' : text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index == 0 ? null : _prev,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _index >= total - 1 ? null : _next,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tip: tap the card to flip.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

