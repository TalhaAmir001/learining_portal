import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/data_models/support_ticket/support_ticket_data_model.dart';
import 'package:learining_portal/network/domain/support_tickets_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';

/// submitted_by_role for API: student | parent (guardian -> parent).
String _submittedByRole(UserType userType) {
  if (userType == UserType.guardian) return 'parent';
  if (userType == UserType.student) return 'student';
  return 'student';
}

class SupportTicketsProvider with ChangeNotifier {
  List<SupportTicketModel> _tickets = [];
  List<SupportTicketCategoryModel> _categories = [];
  bool _isLoadingTickets = false;
  bool _isLoadingCategories = false;
  String? _error;

  List<SupportTicketModel> get tickets => List.unmodifiable(_tickets);
  List<SupportTicketCategoryModel> get categories =>
      List.unmodifiable(_categories);
  bool get isLoadingTickets => _isLoadingTickets;
  bool get isLoadingCategories => _isLoadingCategories;
  String? get error => _error;

  /// Load tickets for current user. Student/guardian: their submitted tickets. Admin/teacher: all tickets (staff API).
  Future<void> loadTickets(AuthProvider auth) async {
    final user = auth.currentUser;
    if (user == null) {
      _tickets = [];
      _error = 'Not logged in';
      notifyListeners();
      return;
    }
    _isLoadingTickets = true;
    _error = null;
    notifyListeners();

    if (user.userType == UserType.admin || user.userType == UserType.teacher) {
      _tickets = await SupportTicketsRepository.getTicketsForStaff();
    } else {
      final role = _submittedByRole(user.userType);
      final id = user.id;
      if (id == null || id.isEmpty) {
        _tickets = [];
        _error = 'User ID not available';
        _isLoadingTickets = false;
        notifyListeners();
        return;
      }
      _tickets = await SupportTicketsRepository.getTickets(
        submittedByRole: role,
        submittedById: id,
      );
    }
    _isLoadingTickets = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    _error = null;
    notifyListeners();
    _categories = await SupportTicketsRepository.getCategories();
    _isLoadingCategories = false;
    notifyListeners();
  }

  /// Create ticket. Returns map with success, ticket_id, id or error.
  Future<Map<String, dynamic>> createTicket({
    required AuthProvider auth,
    required String subject,
    String? category,
    String? priority,
    int? relatedStudentId,
    String? description,
    String? attachment,
  }) async {
    final user = auth.currentUser;
    if (user == null) return {'success': false, 'error': 'Not logged in'};
    final id = user.id;
    if (id == null || id.isEmpty) return {'success': false, 'error': 'User ID not available'};

    final result = await SupportTicketsRepository.createTicket(
      subject: subject,
      submittedByRole: _submittedByRole(user.userType),
      submittedById: id,
      category: category,
      priority: priority,
      relatedStudentId: relatedStudentId,
      description: description,
      attachment: attachment,
    );
    if (result['success'] == true) {
      await loadTickets(auth);
    }
    return result;
  }

  Future<SupportTicketModel?> getTicketDetail({
    required AuthProvider auth,
    required int ticketId,
  }) async {
    final user = auth.currentUser;
    if (user == null) return null;

    if (user.userType == UserType.admin || user.userType == UserType.teacher) {
      return SupportTicketsRepository.getTicketDetailForStaff(ticketId);
    }
    final id = user.id;
    if (id == null || id.isEmpty) return null;

    return SupportTicketsRepository.getTicketDetail(
      ticketId: ticketId,
      submittedByRole: _submittedByRole(user.userType),
      submittedById: id,
    );
  }

  /// Add reply and refresh ticket. Returns success/error map.
  /// Admin/teacher use uid as reply_by_id with reply_by='staff' (no user.id needed).
  Future<Map<String, dynamic>> addReply({
    required AuthProvider auth,
    required int supportTicketId,
    required String message,
    String? attachment,
  }) async {
    final user = auth.currentUser;
    if (user == null) return {'success': false, 'error': 'Not logged in'};

    if (user.userType == UserType.admin || user.userType == UserType.teacher) {
      final staffId = user.uid;
      if (staffId.isEmpty) return {'success': false, 'error': 'Staff ID not available'};
      return SupportTicketsRepository.addReply(
        supportTicketId: supportTicketId,
        replyBy: 'staff',
        replyById: staffId,
        message: message,
        attachment: attachment,
      );
    }

    final id = user.id;
    if (id == null || id.isEmpty) return {'success': false, 'error': 'User ID not available'};

    final result = await SupportTicketsRepository.addReply(
      supportTicketId: supportTicketId,
      replyBy: _submittedByRole(user.userType),
      replyById: id,
      message: message,
      attachment: attachment,
    );
    return result;
  }

  Future<Map<String, dynamic>> uploadAttachment(File file) async {
    return SupportTicketsRepository.uploadAttachment(file);
  }
}
