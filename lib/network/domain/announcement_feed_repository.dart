import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/announcement/announcement_models.dart';
import 'package:learining_portal/utils/api_client.dart';

class AnnouncementFeedRepository {
  static Future<AnnouncementListPayload> getForStudent({
    required int studentId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_announcement_posts_student.php',
        body: {'student_id': studentId},
      );
      return AnnouncementListPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AnnouncementFeedRepository getForStudent: ${e.message}');
      return AnnouncementListPayload(success: false, items: const [], error: e.message);
    }
  }

  static Future<AnnouncementListPayload> getForAdmin() async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_announcement_posts_admin.php',
      );
      return AnnouncementListPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AnnouncementFeedRepository getForAdmin: ${e.message}');
      return AnnouncementListPayload(success: false, items: const [], error: e.message);
    }
  }

  static Future<Map<String, dynamic>> upsertAdmin({
    int? id,
    required int classId,
    required int sectionId,
    required String title,
    required String body,
    required bool isPublished,
    required String mediaChoice, // none|image|video_upload|video_embed
    String? embedProvider,
    String? embedUrl,
    String? mediaFilePath,
    int? createdByStaffId,
  }) {
    return ApiClient.postMultipart(
      endpoint: '/mobile_apis/post_announcement_upsert.php',
      fields: {
        'id': id,
        'class_id': classId,
        'section_id': sectionId,
        'title': title,
        'body': body,
        'is_published': isPublished ? 1 : 0,
        'media_choice': mediaChoice,
        'embed_provider': embedProvider ?? '',
        'embed_url': embedUrl ?? '',
        'created_by_staff_id': createdByStaffId,
      },
      filePath: mediaFilePath,
      fileFieldName: 'media_file',
    );
  }

  static Future<Map<String, dynamic>> deleteAdmin({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_announcement_delete.php',
      body: {'id': id},
    );
  }
}

