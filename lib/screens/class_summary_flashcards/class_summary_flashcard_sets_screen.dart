import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/class_summary_flashcards/class_summary_flashcards_models.dart';
import 'package:learining_portal/network/domain/class_summary_flashcards_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/class_summary_flashcards/class_summary_flashcard_study_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/class_summary_formatters.dart';
import 'package:provider/provider.dart';

/// Folder colours aligned with web `.fc-pal-0` … `.fc-pal-5`.
List<LinearGradient> _folderGradients() => const [
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5c7a99), Color(0xFF6b8aa8)],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2f6f9a), Color(0xFF3c8dbc)],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8f7a4a), Color(0xFFa6906a)],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4a8a6a), Color(0xFF5fa080)],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6a5688), Color(0xFF8575a3)],
      ),
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3a8a9a), Color(0xFF4aa0b0)],
      ),
    ];

int _folderPaletteIndex(String subject) => subject.hashCode.abs() % 6;

class ClassSummaryFlashcardSetsScreen extends StatefulWidget {
  const ClassSummaryFlashcardSetsScreen({super.key});

  @override
  State<ClassSummaryFlashcardSetsScreen> createState() =>
      _ClassSummaryFlashcardSetsScreenState();
}

class _ClassSummaryFlashcardSetsScreenState extends State<ClassSummaryFlashcardSetsScreen> {
  bool _loading = true;
  String? _error;
  List<ClassSummaryFlashcardSetListItem> _items = const [];
  int _subjectIndex = 0;
  int _deckIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _studentIdFromAuth(AuthProvider auth) {
    return auth.effectiveStudentId();
  }

  Map<String, List<ClassSummaryFlashcardSetListItem>> _buildHub() {
    final hub = <String, List<ClassSummaryFlashcardSetListItem>>{};
    for (final row in _items) {
      final sub = row.className.trim().isNotEmpty ? row.className.trim() : 'Class';
      hub.putIfAbsent(sub, () => []).add(row);
    }
    for (final list in hub.values) {
      list.sort((a, b) => b.classDate.compareTo(a.classDate));
    }
    return hub;
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final studentId = _studentIdFromAuth(auth);
    if (studentId == null) {
      setState(() {
        _loading = false;
        _error = 'Flashcards are available for student accounts.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload =
          await ClassSummaryFlashcardsRepository.getForStudent(studentId: studentId);
      if (!payload.success) {
        _error = payload.error ?? 'Failed to load flashcards.';
        _items = const [];
      } else {
        _items = payload.items;
        if (_items.isEmpty) {
          _error = null;
        }
        _subjectIndex = 0;
        _deckIndex = 0;
      }
    } catch (e) {
      _error = e.toString();
      _items = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectSubject(int i, List<String> keys) {
    setState(() {
      _subjectIndex = i.clamp(0, keys.length - 1);
      _deckIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = _buildHub();
    final keys = hub.keys.toList()
      ..sort((a, b) {
        final la = a.toLowerCase();
        final lb = b.toLowerCase();
        final c = la.compareTo(lb);
        if (c != 0) return c;
        return a.compareTo(b);
      });
    final decks = keys.isEmpty ? const <ClassSummaryFlashcardSetListItem>[] : hub[keys[_subjectIndex.clamp(0, keys.length - 1)]]!;
    final selectedDeck = decks.isEmpty
        ? null
        : decks[_deckIndex.clamp(0, decks.length - 1)];

    return SiThemedPageScaffold(
      title: 'Flashcards',
      subtitle:
          'Go from subject to class summary, then open the flashcard deck for that summary.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _items.isEmpty
              ? SiEmptyState(
                  icon: Icons.inbox_outlined,
                  title: _error != null ? 'Nothing to show' : 'No flashcard decks yet',
                  message: _error ??
                      'When your teachers add decks from class summaries, they will appear in the folders.',
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 760;
                      final pad = const EdgeInsets.fromLTRB(10, 12, 10, 28);
                      if (wide) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: pad,
                          child: _HubBoard(
                            keys: keys,
                            hub: hub,
                            subjectIndex: _subjectIndex.clamp(0, keys.length - 1),
                            deckIndex: selectedDeck == null ? 0 : _deckIndex.clamp(0, decks.length - 1),
                            onSubject: (i) => _selectSubject(i, keys),
                            onDeck: (i) => setState(() => _deckIndex = i),
                            selectedDeck: selectedDeck,
                            studentId: _studentIdFromAuth(context.read<AuthProvider>())!,
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: pad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
            _SubjectColumn(
              keys: keys,
              selectedIndex: _subjectIndex.clamp(0, keys.length - 1),
              onSelect: (i) => _selectSubject(i, keys),
              expandList: false,
            ),
                            const SizedBox(height: 12),
                            _DeckColumn(
                              subjectLabel: keys[_subjectIndex.clamp(0, keys.length - 1)],
                              decks: decks,
                              selectedIndex: _deckIndex.clamp(0, decks.isEmpty ? 0 : decks.length - 1),
                              onSelect: (i) => setState(() => _deckIndex = i),
                              expandList: false,
                            ),
                            const SizedBox(height: 12),
                            if (selectedDeck != null)
                              _DetailColumn(
                                deck: selectedDeck,
                                studentId: _studentIdFromAuth(context.read<AuthProvider>())!,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _HubBoard extends StatelessWidget {
  const _HubBoard({
    required this.keys,
    required this.hub,
    required this.subjectIndex,
    required this.deckIndex,
    required this.onSubject,
    required this.onDeck,
    required this.selectedDeck,
    required this.studentId,
  });

  final List<String> keys;
  final Map<String, List<ClassSummaryFlashcardSetListItem>> hub;
  final int subjectIndex;
  final int deckIndex;
  final ValueChanged<int> onSubject;
  final ValueChanged<int> onDeck;
  final ClassSummaryFlashcardSetListItem? selectedDeck;
  final int studentId;

  @override
  Widget build(BuildContext context) {
    final decks = hub[keys[subjectIndex]] ?? const [];
    final d = selectedDeck;
    final h = (MediaQuery.sizeOf(context).height * 0.52).clamp(320.0, 520.0);
    return SizedBox(
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E4EA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _SubjectColumn(
                    keys: keys,
                    selectedIndex: subjectIndex,
                    onSelect: onSubject,
                  ),
                ),
              ),
            ),
            const _Connector(),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _DeckColumn(
                  subjectLabel: keys[subjectIndex],
                  decks: decks,
                  selectedIndex: deckIndex.clamp(0, decks.isEmpty ? 0 : decks.length - 1),
                  onSelect: onDeck,
                ),
              ),
            ),
            const _Connector(),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: d == null
                    ? const Center(child: Text('Pick a summary'))
                    : _DetailColumn(deck: d, studentId: studentId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      alignment: Alignment.center,
      color: const Color(0xFFF5F5F5),
      child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
    );
  }
}

class _SubjectColumn extends StatelessWidget {
  const _SubjectColumn({
    required this.keys,
    required this.selectedIndex,
    required this.onSelect,
    this.expandList = true,
  });

  final List<String> keys;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final grads = _folderGradients();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SUBJECT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.blueGrey.shade300,
          ),
        ),
        const SizedBox(height: 8),
        if (expandList)
          Expanded(
            child: ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _subjectTile(context, grads, i),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _subjectTile(context, grads, i),
            ),
          ),
      ],
    );
  }

  Widget _subjectTile(BuildContext context, List<LinearGradient> grads, int i) {
    final active = i == selectedIndex;
    final g = grads[_folderPaletteIndex(keys[i])];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: g,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.22 : 0.12),
                blurRadius: active ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: active ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  keys[i],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckColumn extends StatelessWidget {
  const _DeckColumn({
    required this.subjectLabel,
    required this.decks,
    required this.selectedIndex,
    required this.onSelect,
    this.expandList = true,
  });

  final String subjectLabel;
  final List<ClassSummaryFlashcardSetListItem> decks;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CLASS SUMMARIES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.blueGrey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FC),
            borderRadius: BorderRadius.circular(6),
            border: const Border(left: BorderSide(color: Color(0xFF3c8dbc), width: 3)),
          ),
          child: Text(
            subjectLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1a4d7a),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Summaries for this subject (each has one deck)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (expandList)
          Expanded(
            child: ListView.separated(
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _deckTile(context, i),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _deckTile(context, i),
            ),
          ),
      ],
    );
  }

  Widget _deckTile(BuildContext context, int i) {
    final d = decks[i];
    final active = i == selectedIndex;
    final badge = d.isNew ? 'New' : 'Review';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE8F4FC) : const Color(0xFFFBFDFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFF3c8dbc) : const Color(0xFFDCE4EC),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  d.displayTopic,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF3c8dbc) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  const _DetailColumn({required this.deck, required this.studentId});

  final ClassSummaryFlashcardSetListItem deck;
  final int studentId;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatClassSummaryListDate(deck.classDate);
    final sec = deck.sectionName.trim();
    final isNew = deck.isNew;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FLASHCARD DECK',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.blueGrey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9F6),
            borderRadius: BorderRadius.circular(6),
            border: const Border(left: BorderSide(color: Color(0xFF5cb85c), width: 3)),
          ),
          child: Text(
            deck.displayTopic.length > 42 ? '${deck.displayTopic.substring(0, 40)}…' : deck.displayTopic,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF2d5a45),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(dateLabel, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            if (sec.isNotEmpty) ...[
              Text('  ·  ', style: TextStyle(color: Colors.grey.shade500)),
              Icon(Icons.group_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sec,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isNew ? const Color(0xFFFFF3CD) : const Color(0xFFD4EDDA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isNew ? const Color(0xFFFFC107) : const Color(0xFF5cb85c),
              ),
            ),
            child: Text(
              isNew ? 'Not opened yet' : 'Started before',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isNew ? const Color(0xFF856404) : const Color(0xFF155724),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ClassSummaryFlashcardStudyScreen(
                  setId: deck.id,
                  studentId: studentId,
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF3c8dbc),
          ),
          child: const Text('Study flashcards', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
