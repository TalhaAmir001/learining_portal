import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/utils/api_client.dart';

class ShareContentRepository {
  static Future<List<DcContentTypeModel>> getContentTypes() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_dc_content_types.php');
      if (r['success'] == true && r['content_types'] != null) {
        return (r['content_types'] as List<dynamic>)
            .map((e) => DcContentTypeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getContentTypes: ${e.message}');
      return [];
    }
  }

  /// When [uploadBy] is set (>0), only files uploaded by that staff id (must exist in `staff`).
  static Future<List<DcUploadContentModel>> getUploadContents({
    int limit = 300,
    int? uploadBy,
  }) async {
    try {
      final qp = <String, String>{'limit': limit.toString()};
      if (uploadBy != null && uploadBy > 0) {
        qp['upload_by'] = uploadBy.toString();
      }
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_dc_upload_contents.php',
        queryParameters: qp,
      );
      if (r['success'] == true && r['items'] != null) {
        return (r['items'] as List<dynamic>)
            .map((e) => DcUploadContentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getUploadContents: ${e.message}');
      return [];
    }
  }

  static Future<List<DcVideoTutorialModel>> getVideoTutorials({int limit = 150}) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_dc_video_tutorials.php',
        queryParameters: {'limit': limit.toString()},
      );
      if (r['success'] == true && r['tutorials'] != null) {
        return (r['tutorials'] as List<dynamic>)
            .map((e) => DcVideoTutorialModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getVideoTutorials: ${e.message}');
      return [];
    }
  }

  /// When [listAll] is true, returns all shares (admin-style). Otherwise pass [createdBy] to match
  /// web “my shares” (`share_contents.created_by`).
  static Future<List<DcShareContentModel>> getShareContents({
    int limit = 200,
    int? createdBy,
    bool listAll = false,
  }) async {
    try {
      final qp = <String, String>{'limit': limit.toString()};
      if (listAll) {
        qp['list_all'] = '1';
      } else {
        if (createdBy == null || createdBy <= 0) {
          return [];
        }
        qp['created_by'] = createdBy.toString();
      }
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_dc_share_contents.php',
        queryParameters: qp,
      );
      if (r['success'] == true && r['shares'] != null) {
        return (r['shares'] as List<dynamic>)
            .map((e) => DcShareContentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getShareContents: ${e.message}');
      return [];
    }
  }

  /// Uploads a file into the download center (`upload_contents`). Uses multipart field `file`.
  /// Pass either [filePath] (mobile/desktop) or [fileBytes] (e.g. web) plus [filename].
  static Future<Map<String, dynamic>> uploadDcContent({
    required int contentTypeId,
    int uploadBy = 0,
    required String filename,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    if ((filePath == null || filePath.isEmpty) &&
        (fileBytes == null || fileBytes.isEmpty)) {
      return {'success': false, 'error': 'No file selected.'};
    }
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiClient.baseUrl,
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
      final MultipartFile part;
      if (filePath != null && filePath.isNotEmpty) {
        part = await MultipartFile.fromFile(
          filePath,
          filename: filename,
        );
      } else {
        part = MultipartFile.fromBytes(
          fileBytes!,
          filename: filename,
        );
      }
      final formData = FormData.fromMap({
        'file': part,
        'content_type_id': contentTypeId.toString(),
        'upload_by': uploadBy.toString(),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/mobile_apis/upload_dc_upload_content.php',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      if (data == null) {
        return {'success': false, 'error': 'Invalid response'};
      }
      if (data['success'] == true) {
        return {
          'success': true,
          'id': data['id'],
          'message': data['message']?.toString(),
        };
      }
      return _uploadDcFailureMap(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        final m = Map<String, dynamic>.from(body);
        if (m['success'] == false) {
          return _uploadDcFailureMap(m);
        }
      }
      String? msg;
      if (body is Map) {
        msg = _formatDcUploadServerMessage(Map<String, dynamic>.from(body));
      } else if (body is String) {
        msg = body;
      }
      return {
        'success': false,
        'error': msg ?? e.message ?? e.toString(),
        'http_status': e.response?.statusCode,
      };
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> _uploadDcFailureMap(Map<String, dynamic> data) {
    final composed = _formatDcUploadServerMessage(data);
    return {
      ...data,
      'success': false,
      'error': composed,
    };
  }

  /// Human-readable block for dialogs / logs (pass the map returned by [uploadDcContent] on failure).
  static String formatDcUploadErrorForDisplay(Map<String, dynamic> result) {
    final e = result['error']?.toString();
    if (e != null && e.isNotEmpty) {
      return e;
    }
    return _formatDcUploadServerMessage(result);
  }

  static String _formatDcUploadServerMessage(Map<String, dynamic> data) {
    final parts = <String>[];
    final main = data['error']?.toString();
    if (main != null && main.isNotEmpty) {
      parts.add(main);
    }
    final details = data['details']?.toString();
    if (details != null && details.isNotEmpty && details != main) {
      parts.add(details);
    }
    final errno = data['mysql_errno'];
    final sqlErr = data['mysql_error']?.toString();
    if (sqlErr != null && sqlErr.isNotEmpty) {
      parts.add('MySQL errno ${errno ?? '?'}: $sqlErr');
    }
    final http = data['http_status'];
    if (http != null) {
      parts.add('HTTP status: $http');
    }
    final ubReq = data['upload_by_requested'];
    final ubUsed = data['upload_by_used'];
    if (ubReq != null || ubUsed != null) {
      parts.add('upload_by (client): ${ubReq ?? '—'}  →  used staff id: ${ubUsed ?? '—'}');
    }
    final note = data['resolver_note']?.toString() ?? data['upload_by_resolver_note']?.toString();
    if (note != null && note.isNotEmpty) {
      parts.add('Resolver: $note');
    }
    if (parts.isEmpty) {
      return data['error']?.toString() ?? 'Upload failed';
    }
    return parts.join('\n\n');
  }

  static Future<DcShareFormMeta?> getShareFormMeta() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_dc_share_form_meta.php');
      if (r['success'] == true && r['roles'] != null) {
        final roles = (r['roles'] as List<dynamic>)
            .map((e) => DcShareRoleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final g = r['guardian_option'];
        final guardian = g == true || g == 1 || g == '1';
        return DcShareFormMeta(guardianOption: guardian, roles: roles);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getShareFormMeta: ${e.message}');
      return null;
    }
  }

  static Future<List<DcClassSectionOptionModel>> getClassSectionsForShare() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_dc_class_sections.php');
      if (r['success'] == true && r['class_sections'] != null) {
        return (r['class_sections'] as List<dynamic>)
            .map((e) => DcClassSectionOptionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ShareContentRepository getClassSectionsForShare: ${e.message}');
      return [];
    }
  }

  /// Creates share_contents + links (same flow as web admin Content → Share).
  static Future<Map<String, dynamic>> createShare(Map<String, dynamic> body) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/create_dc_share_content.php',
        body: body,
      );
      if (r['success'] == true) {
        return {
          'success': true,
          'share_id': r['share_id'],
          'shared_url': r['shared_url']?.toString(),
          'message': r['message']?.toString(),
        };
      }
      return {
        'success': false,
        'error': r['error']?.toString() ?? 'Share failed',
        'mysql_errno': r['mysql_errno'],
        'mysql_error': r['mysql_error']?.toString(),
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }
}
