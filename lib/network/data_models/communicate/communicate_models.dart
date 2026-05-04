class CommMessageListModel {
  final int id;
  final String title;
  final String sendThrough;
  final String message;
  final String sendMail;
  final String sendSms;
  final String sendTo;
  final int? sent;
  final String scheduleDateTime;
  final String createdAt;

  CommMessageListModel({
    required this.id,
    required this.title,
    required this.sendThrough,
    required this.message,
    required this.sendMail,
    required this.sendSms,
    required this.sendTo,
    this.sent,
    required this.scheduleDateTime,
    required this.createdAt,
  });

  factory CommMessageListModel.fromJson(Map<String, dynamic> json) {
    final sentRaw = json['sent'];
    return CommMessageListModel(
      id: _i(json['id']),
      title: _s(json['title']),
      sendThrough: _s(json['send_through']),
      message: _s(json['message']),
      sendMail: _s(json['send_mail']),
      sendSms: _s(json['send_sms']),
      sendTo: _s(json['send_to']),
      sent: sentRaw == null ? null : _i(sentRaw),
      scheduleDateTime: _s(json['schedule_date_time']),
      createdAt: _s(json['created_at']),
    );
  }

  String get preview {
    final m = message.trim();
    if (m.length <= 80) return m;
    return '${m.substring(0, 80)}…';
  }
}

class CommTemplateModel {
  final int id;
  final String title;
  final String message;
  final String createdAt;
  final String updatedAt;

  CommTemplateModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.updatedAt = '',
  });

  factory CommTemplateModel.fromJson(Map<String, dynamic> json) {
    return CommTemplateModel(
      id: _i(json['id']),
      title: _s(json['title']),
      message: _s(json['message']),
      createdAt: _s(json['created_at']),
      updatedAt: _s(json['updated_at']),
    );
  }
}

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}
