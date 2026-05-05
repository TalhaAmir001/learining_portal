class AnnouncementPost {
  AnnouncementPost({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.sectionId,
    required this.title,
    required this.body,
    required this.mediaType,
    required this.embedProvider,
    required this.embedUrl,
    required this.mediaPath,
    required this.createdByStaffId,
    required this.createdAt,
    required this.updatedAt,
    required this.isPublished,
    required this.staffFirstname,
    required this.staffSurname,
    required this.className,
    required this.sectionName,
  });

  final int id;
  final int sessionId;
  final int classId;
  final int sectionId;
  final String title;
  final String body;
  final String mediaType; // none|image|video_embed|video_upload
  final String embedProvider;
  final String embedUrl;
  final String mediaPath;
  final int createdByStaffId;
  final String createdAt;
  final String updatedAt;
  final bool isPublished;
  final String staffFirstname;
  final String staffSurname;
  final String className;
  final String sectionName;

  String get authorName {
    final n = ('$staffFirstname $staffSurname').trim();
    return n.isEmpty ? 'School' : n;
  }

  factory AnnouncementPost.fromJson(Map<String, dynamic> json) {
    int i(String k) => int.tryParse(json[k]?.toString() ?? '') ?? 0;
    String s(String k) => (json[k] ?? '').toString();
    bool b(String k) {
      final v = json[k];
      if (v is bool) return v;
      final n = int.tryParse(v?.toString() ?? '');
      if (n != null) return n == 1;
      return (v?.toString() ?? '') == '1';
    }

    return AnnouncementPost(
      id: i('id'),
      sessionId: i('session_id'),
      classId: i('class_id'),
      sectionId: i('section_id'),
      title: s('title'),
      body: s('body'),
      mediaType: s('media_type'),
      embedProvider: s('embed_provider'),
      embedUrl: s('embed_url'),
      mediaPath: s('media_path'),
      createdByStaffId: i('created_by_staff_id'),
      createdAt: s('created_at'),
      updatedAt: s('updated_at'),
      isPublished: b('is_published'),
      staffFirstname: s('staff_firstname'),
      staffSurname: s('staff_surname'),
      className: s('class_name'),
      sectionName: s('section_name'),
    );
  }
}

class AnnouncementListPayload {
  AnnouncementListPayload({
    required this.success,
    required this.items,
    this.error,
  });

  final bool success;
  final List<AnnouncementPost> items;
  final String? error;

  factory AnnouncementListPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AnnouncementPost.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <AnnouncementPost>[];
    return AnnouncementListPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      items: items,
    );
  }
}

