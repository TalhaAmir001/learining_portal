import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/network/domain/daily_feedback_repository.dart';

/// Provider for daily feedback: list, classes, sections, students, and save/upload.
class DailyFeedbackProvider with ChangeNotifier {
  List<DailyFeedbackModel> _feedbacks = [];
  bool _loadingFeedbacks = false;
  String? _feedbacksError;

  List<FeedbackClassModel> _classes = [];
  List<FeedbackSectionModel> _sections = [];
  List<FeedbackStudentModel> _students = [];
  bool _loadingClasses = false;
  bool _loadingSections = false;
  bool _loadingStudents = false;
  String? _classesError;
  String? _sectionsError;
  String? _studentsError;

  bool _saving = false;
  String? _saveError;

  // Getters
  List<DailyFeedbackModel> get feedbacks => List.unmodifiable(_feedbacks);
  bool get loadingFeedbacks => _loadingFeedbacks;
  String? get feedbacksError => _feedbacksError;

  List<FeedbackClassModel> get classes => List.unmodifiable(_classes);
  List<FeedbackSectionModel> get sections => List.unmodifiable(_sections);
  List<FeedbackStudentModel> get students => List.unmodifiable(_students);
  bool get loadingClasses => _loadingClasses;
  bool get loadingSections => _loadingSections;
  bool get loadingStudents => _loadingStudents;
  String? get classesError => _classesError;
  String? get sectionsError => _sectionsError;
  String? get studentsError => _studentsError;

  bool get saving => _saving;
  String? get saveError => _saveError;

  /// Feedback for today (one per day), if any.
  DailyFeedbackModel? get todayFeedback {
    for (final f in _feedbacks) {
      if (_isToday(f.createdAt)) return f;
    }
    return null;
  }

  static bool _isToday(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return false;
    try {
      final d = DateTime.parse(createdAt);
      final n = DateTime.now();
      return d.year == n.year && d.month == n.month && d.day == n.day;
    } catch (_) {
      return false;
    }
  }

  /// Load all feedbacks for the given staff. Requires [staffId] (e.g. from AuthProvider.currentUser?.uid).
  Future<void> loadFeedbacks(String? staffId) async {
    if (staffId == null || staffId.isEmpty) {
      _feedbacks = [];
      _loadingFeedbacks = false;
      _feedbacksError = null;
      notifyListeners();
      return;
    }

    _loadingFeedbacks = true;
    _feedbacksError = null;
    notifyListeners();

    final list = await DailyFeedbackRepository.getFeedbacks(staffId: staffId);

    _feedbacks = list;
    _loadingFeedbacks = false;
    _feedbacksError = null;
    notifyListeners();
  }

  /// Load classes and sections (for feedback form targeting). Call once when opening the form.
  Future<void> loadClassesAndSections() async {
    _loadingClasses = true;
    _loadingSections = true;
    _classesError = null;
    _sectionsError = null;
    notifyListeners();

    final results = await Future.wait([
      DailyFeedbackRepository.getClasses(),
      DailyFeedbackRepository.getSections(),
    ]);

    _classes = results[0] as List<FeedbackClassModel>;
    _sections = results[1] as List<FeedbackSectionModel>;
    _loadingClasses = false;
    _loadingSections = false;
    _classesError = null;
    _sectionsError = null;
    notifyListeners();
  }

  /// Load students for the given class and section (from fl_chat_users).
  Future<void> loadStudents(int classId, int sectionId) async {
    _loadingStudents = true;
    _studentsError = null;
    _students = [];
    notifyListeners();

    final list = await DailyFeedbackRepository.getFeedbackStudents(
      classId: classId,
      sectionId: sectionId,
    );

    _students = list;
    _loadingStudents = false;
    _studentsError = null;
    notifyListeners();
  }

  /// Clear students list (e.g. when class or section is cleared).
  void clearStudents() {
    _students = [];
    _studentsError = null;
    notifyListeners();
  }

  /// Upload a file (voice or document). Returns map with 'success', 'file_url', 'filename' or 'error'.
  Future<Map<String, dynamic>> uploadFile(File file) async {
    return DailyFeedbackRepository.uploadFeedbackFile(file);
  }

  /// Save or update daily feedback. Returns true on success, false otherwise; [saveError] is set on failure.
  Future<bool> saveFeedback({
    required String staffId,
    int? feedbackId,
    int? classId,
    int? sectionId,
    List<int>? recipientStudentIds,
    String? messageText,
    String? voiceUrl,
    List<String>? attachmentUrls,
  }) async {
    _saving = true;
    _saveError = null;
    notifyListeners();

    final result = await DailyFeedbackRepository.saveFeedback(
      staffId: staffId,
      feedbackId: feedbackId,
      classId: classId,
      sectionId: sectionId,
      recipientStudentIds: recipientStudentIds,
      messageText: messageText,
      voiceUrl: voiceUrl,
      attachmentUrls: attachmentUrls,
    );

    _saving = false;
    if (result['success'] == true) {
      _saveError = null;
      notifyListeners();
      return true;
    }

    _saveError = result['error']?.toString() ?? 'Failed to save feedback';
    notifyListeners();
    return false;
  }

  /// Clear save error (e.g. when user edits the form again).
  void clearSaveError() {
    _saveError = null;
    notifyListeners();
  }

  /// Clear feedbacks error.
  void clearFeedbacksError() {
    _feedbacksError = null;
    notifyListeners();
  }
}
