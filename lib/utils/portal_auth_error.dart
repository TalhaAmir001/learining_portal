import 'package:html/parser.dart' as html_parser;

/// Extracts a plain-text message from portal `Gauthenticate` login errors.
///
/// The web backend often returns:
/// `{ "status": 1, "error": { "error_message": "<div class='alert alert-danger'>...</div>" } }`
String? parsePortalAuthErrorMessage(dynamic error) {
  if (error == null) return null;

  if (error is String) {
    final text = _htmlToPlainText(error);
    return text.isEmpty ? null : text;
  }

  if (error is Map) {
    final errorMessage = error['error_message'];
    if (errorMessage != null) {
      final text = _htmlToPlainText(errorMessage.toString());
      if (text.isNotEmpty) return text;
    }

    final parts = <String>[];
    for (final entry in error.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty || key == 'error_message') continue;
      final value = _htmlToPlainText(entry.value?.toString() ?? '');
      if (value.isNotEmpty) parts.add(value);
    }
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
  }

  final fallback = _htmlToPlainText(error.toString());
  return fallback.isEmpty ? null : fallback;
}

String _htmlToPlainText(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';

  if (text.contains('<') && text.contains('>')) {
    final parsed = html_parser.parseFragment(text);
    text = parsed.text ?? text;
  }

  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
