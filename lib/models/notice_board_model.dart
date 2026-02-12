import 'package:learining_portal/network/data_models/notice_board/send_notification_data_model.dart';

/// App-level model for a notice from send_notifications (for dashboard and detail screen).
class NoticeBoardModel {
  final int id;
  final String title;
  final String? message;
  final DateTime? publishDate;
  final DateTime? date;
  final String? attachment;
  final String? createdBy;
  final DateTime? createdAt;

  NoticeBoardModel({
    required this.id,
    required this.title,
    this.message,
    this.publishDate,
    this.date,
    this.attachment,
    this.createdBy,
    this.createdAt,
  });

  factory NoticeBoardModel.fromSendNotification(SendNotificationDataModel n) {
    return NoticeBoardModel(
      id: n.id,
      title: n.title ?? 'Notice',
      message: n.message,
      publishDate: n.publishDate,
      date: n.date,
      attachment: n.attachment,
      createdBy: n.createdBy,
      createdAt: n.createdAt,
    );
  }
}
