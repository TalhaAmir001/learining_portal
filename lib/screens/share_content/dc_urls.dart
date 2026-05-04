import 'package:learining_portal/utils/api_client.dart';

bool dcLooksLikeHttpUrl(String s) {
  final t = s.trim().toLowerCase();
  return t.startsWith('http://') || t.startsWith('https://');
}

/// Resolves portal-relative upload paths to a full URL under [ApiClient.baseUrl].
String dcResolvePortalFileUrl(String dirPath, String fileName) {
  final name = fileName.trim();
  if (name.isEmpty) return '';
  if (dcLooksLikeHttpUrl(name)) return name.trim();

  final base = ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
  var dir = dirPath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  if (dir.startsWith('http://') || dir.startsWith('https://')) {
    final d = dir.replaceAll(RegExp(r'/$'), '');
    return '$d/${name.replaceAll(RegExp(r'^/+'), '')}';
  }
  final d = dir.replaceAll(RegExp(r'^/+'), '');
  if (d.isEmpty) return '$base/${name.replaceAll(RegExp(r'^/+'), '')}';
  return '$base/$d/${name.replaceAll(RegExp(r'^/+'), '')}';
}
