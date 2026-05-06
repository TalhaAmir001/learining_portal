class ClassSummaryFlashcard {
  ClassSummaryFlashcard({
    required this.front,
    required this.back,
  });

  final String front;
  final String back;

  factory ClassSummaryFlashcard.fromJson(Map<String, dynamic> json) {
    String s(String k) => (json[k] ?? '').toString();
    return ClassSummaryFlashcard(
      front: s('front'),
      back: s('back'),
    );
  }
}

class ClassSummaryFlashcardSetListItem {
  ClassSummaryFlashcardSetListItem({
    required this.id,
    required this.classSummaryId,
    required this.classId,
    required this.sectionId,
    required this.createdAt,
    required this.summaryTitle,
    required this.classDate,
    required this.className,
    required this.sectionName,
    required this.firstOpenedAt,
    required this.lastOpenedAt,
    required this.completedAt,
  });

  final int id;
  final int classSummaryId;
  final int classId;
  final int sectionId;
  final String createdAt;
  final String summaryTitle;
  final String classDate;
  final String className;
  final String sectionName;
  final String? firstOpenedAt;
  final String? lastOpenedAt;
  final String? completedAt;

  bool get isNew => (firstOpenedAt ?? '').trim().isEmpty;
  bool get isCompleted => (completedAt ?? '').trim().isNotEmpty;

  String get displayTopic {
    final t = summaryTitle.trim();
    if (t.isNotEmpty) return t;
    return 'Class summary • $classDate';
  }

  factory ClassSummaryFlashcardSetListItem.fromJson(Map<String, dynamic> json) {
    int i(String k) => int.tryParse(json[k]?.toString() ?? '') ?? 0;
    String s(String k) => (json[k] ?? '').toString();
    String? sn(String k) {
      final v = json[k];
      if (v == null) return null;
      final out = v.toString();
      return out.isEmpty ? null : out;
    }

    return ClassSummaryFlashcardSetListItem(
      id: i('id'),
      classSummaryId: i('class_summary_id'),
      classId: i('class_id'),
      sectionId: i('section_id'),
      createdAt: s('created_at'),
      summaryTitle: s('summary_title'),
      classDate: s('class_date'),
      className: s('class_name'),
      sectionName: s('section_name'),
      firstOpenedAt: sn('first_opened_at'),
      lastOpenedAt: sn('last_opened_at'),
      completedAt: sn('completed_at'),
    );
  }
}

class ClassSummaryFlashcardSet {
  ClassSummaryFlashcardSet({
    required this.id,
    required this.classSummaryId,
    required this.classId,
    required this.sectionId,
    required this.cardsJson,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.summaryTitle,
    required this.classDate,
    required this.className,
    required this.sectionName,
    required this.cards,
  });

  final int id;
  final int classSummaryId;
  final int classId;
  final int sectionId;
  final String cardsJson;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String summaryTitle;
  final String classDate;
  final String className;
  final String sectionName;
  final List<ClassSummaryFlashcard> cards;

  String get displayTopic {
    final t = summaryTitle.trim();
    if (t.isNotEmpty) return t;
    return 'Class summary • $classDate';
  }

  factory ClassSummaryFlashcardSet.fromJson(Map<String, dynamic> json) {
    int i(String k) => int.tryParse(json[k]?.toString() ?? '') ?? 0;
    String s(String k) => (json[k] ?? '').toString();

    // API returns `cards` either nested under `set` or at top-level; repository passes through.
    final rawCards = json['cards'];
    final cards = rawCards is List
        ? rawCards
            .whereType<Map>()
            .map((e) => ClassSummaryFlashcard.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ClassSummaryFlashcard>[];

    return ClassSummaryFlashcardSet(
      id: i('id'),
      classSummaryId: i('class_summary_id'),
      classId: i('class_id'),
      sectionId: i('section_id'),
      cardsJson: s('cards_json'),
      createdBy: i('created_by'),
      createdAt: s('created_at'),
      updatedAt: s('updated_at'),
      summaryTitle: s('summary_title'),
      classDate: s('class_date'),
      className: s('class_name'),
      sectionName: s('section_name'),
      cards: cards,
    );
  }
}

class ClassSummaryFlashcardSetListPayload {
  ClassSummaryFlashcardSetListPayload({
    required this.success,
    required this.items,
    this.error,
  });

  final bool success;
  final List<ClassSummaryFlashcardSetListItem> items;
  final String? error;

  factory ClassSummaryFlashcardSetListPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => ClassSummaryFlashcardSetListItem.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ClassSummaryFlashcardSetListItem>[];
    return ClassSummaryFlashcardSetListPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      items: items,
    );
  }
}

class ClassSummaryFlashcardSetDetailPayload {
  ClassSummaryFlashcardSetDetailPayload({
    required this.success,
    required this.set,
    this.error,
  });

  final bool success;
  final ClassSummaryFlashcardSet? set;
  final String? error;

  factory ClassSummaryFlashcardSetDetailPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['set'];
    final cards = json['cards'];
    return ClassSummaryFlashcardSetDetailPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      set: raw is Map
          ? ClassSummaryFlashcardSet.fromJson({
              ...raw.cast<String, dynamic>(),
              'cards': cards,
            })
          : null,
    );
  }
}

