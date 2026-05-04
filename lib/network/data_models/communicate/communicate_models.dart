import 'dart:convert';

/// Turns `["student"]` or `student,parent` into readable labels for UI.
String commFormatAudienceSendTo(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.startsWith('[')) {
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) {
        final parts = <String>[];
        for (final e in decoded) {
          final s = e.toString().trim();
          if (s.isEmpty) continue;
          parts.add(_humanizeRoleLabel(s));
        }
        return parts.join(', ');
      }
    } catch (_) {}
  }
  return t;
}

String _humanizeRoleLabel(String role) {
  const map = {
    'student': 'Students',
    'parent': 'Parents',
    'guardian': 'Guardians',
    'teacher': 'Teachers',
    'staff': 'Staff',
    'admin': 'Admins',
  };
  final key = role.toLowerCase();
  if (map.containsKey(key)) return map[key]!;
  if (role.length == 1) return role.toUpperCase();
  return role[0].toUpperCase() + role.substring(1).toLowerCase();
}

/// `["41","42"]` or `41,42` → `41, 42` for subtitles / detail.
String commFormatSectionIds(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.startsWith('[')) {
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
      }
    } catch (_) {}
  }
  return t.replaceAll(RegExp(r'\s*,\s*'), ', ');
}

/// Decodes common entities after HTML tags are stripped (list previews, SMS-style bodies).
String commDecodeHtmlEntities(String input) {
  if (input.isEmpty) return input;
  var s = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8220;', '"')
      .replaceAll('&#8221;', '"');
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '');
    if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
    return String.fromCharCode(code);
  });
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '', radix: 16);
    if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
    return String.fromCharCode(code);
  });
  return s;
}

/// Short date for log rows, e.g. `2026-04-30 18:49:21` → `30 Apr 2026`.
String commFormatLogTimestamp(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  try {
    final dt = DateTime.tryParse(t.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return raw;
  }
}

/// One recipient from `messages.user_list` JSON (email log).
class CommLogRecipient {
  final String userId;
  final String email;
  final String mobile;
  final String role;

  const CommLogRecipient({
    required this.userId,
    required this.email,
    required this.mobile,
    required this.role,
  });
}

bool commParseBoolFlag(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

/// Removes HTML tags and normalizes whitespace for list previews.
String commStripHtml(String? input) {
  if (input == null || input.isEmpty) return '';
  var s = input.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), ' ');
  s = commDecodeHtmlEntities(s);
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Turns stored template HTML into plain text for a multiline editor (paragraphs + decoded entities).
String commHtmlToPlainEmailTemplate(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  var s = html;
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), '');
  s = commDecodeHtmlEntities(s);
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  s = s.replaceAll(RegExp(r'\n[ \t]+'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String _commEscapeHtmlText(String x) {
  return x
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Builds simple HTML from plain editor text (blank line = new `<p>`; single newline = `<br />`).
String commPlainToHtmlEmailBody(String plain) {
  final t = plain.trim();
  if (t.isEmpty) return '<p></p>';
  final blocks = t.split(RegExp(r'\n\s*\n'));
  final buf = StringBuffer();
  for (final block in blocks) {
    final lines = block.split(RegExp(r'\r?\n'));
    final inner = lines.map(_commEscapeHtmlText).join('<br />\n');
    if (inner.trim().isEmpty) continue;
    buf.write('<p>');
    buf.write(inner);
    buf.write('</p>\n');
  }
  final out = buf.toString().trim();
  return out.isEmpty ? '<p></p>' : out;
}

List<CommLogRecipient> commParseRecipients(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) return [];
    final out = <CommLogRecipient>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final mob = _s(m['mobileno']);
      out.add(
        CommLogRecipient(
          userId: _s(m['user_id']),
          email: _s(m['email']),
          mobile: mob.isNotEmpty ? mob : _s(m['mobile']),
          role: _s(m['role']),
        ),
      );
    }
    return out;
  } catch (_) {
    return [];
  }
}

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
  final bool isClassSend;
  final bool isGroupSend;
  final bool isIndividualSend;

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
    this.isClassSend = false,
    this.isGroupSend = false,
    this.isIndividualSend = false,
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
      isClassSend: commParseBoolFlag(json['is_class']),
      isGroupSend: commParseBoolFlag(json['is_group']),
      isIndividualSend: commParseBoolFlag(json['is_individual']),
    );
  }

  String get channelsSummary {
    final mail = commParseBoolFlag(sendMail);
    final sms = commParseBoolFlag(sendSms);
    if (mail && sms) return 'Email & SMS';
    if (mail) return 'Email';
    if (sms) return 'SMS';
    if (sendThrough.isNotEmpty) return sendThrough;
    return '';
  }

  String get audienceSummaryLine {
    final modes = <String>[];
    if (isClassSend) modes.add('Class');
    if (isGroupSend) modes.add('Group');
    if (isIndividualSend) modes.add('Individual');
    final mode = modes.isEmpty ? '' : modes.join(' · ');
    final to = commFormatAudienceSendTo(sendTo);
    if (mode.isEmpty && to.isNotEmpty) return to;
    if (mode.isNotEmpty && to.isNotEmpty) {
      return '$mode · $to';
    }
    if (mode.isNotEmpty) return mode;
    return to;
  }

  String get plainPreview {
    final t = commStripHtml(message);
    if (t.length <= 120) return t;
    return '${t.substring(0, 120)}…';
  }

  /// One-line preview for dense list rows (no HTML / JSON).
  String get logCardPreviewLine {
    final t = commStripHtml(message);
    if (t.isEmpty) return '';
    const max = 96;
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  String get _sentChipLabel {
    if (sent == null) return 'Pending';
    return sent != 0 ? 'Sent' : 'Not sent';
  }

  /// Log / schedule list cards: date · channels · status, then audience, then short preview.
  String get logCardSubtitle {
    final line1 = <String>[
      if (createdAt.isNotEmpty) commFormatLogTimestamp(createdAt),
      if (channelsSummary.isNotEmpty) channelsSummary,
      _sentChipLabel,
    ].join(' · ');
    final aud = audienceSummaryLine;
    final p = logCardPreviewLine;
    return [
      line1,
      if (aud.isNotEmpty) aud,
      if (scheduleDateTime.isNotEmpty) 'Scheduled: $scheduleDateTime',
      if (p.isNotEmpty) p,
    ].join('\n');
  }

  String get preview => plainPreview;
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
