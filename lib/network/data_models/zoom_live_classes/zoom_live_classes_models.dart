/// Zoom Live Classes / Conference mobile API models (see `mobile_apis/zlc_*.php`).

class ZlcSettingsModel {
  final int useTeacherApi;
  final int useZoomApp;
  final int useZoomAppUser;
  final int parentLiveClass;
  final bool oauthTokenConfigured;

  ZlcSettingsModel({
    required this.useTeacherApi,
    required this.useZoomApp,
    required this.useZoomAppUser,
    required this.parentLiveClass,
    required this.oauthTokenConfigured,
  });

  factory ZlcSettingsModel.fromJson(Map<String, dynamic> json) {
    return ZlcSettingsModel(
      useTeacherApi: (json['use_teacher_api'] as num?)?.toInt() ?? 0,
      useZoomApp: (json['use_zoom_app'] as num?)?.toInt() ?? 0,
      useZoomAppUser: (json['use_zoom_app_user'] as num?)?.toInt() ?? 0,
      parentLiveClass: (json['parent_live_class'] as num?)?.toInt() ?? 0,
      oauthTokenConfigured: json['oauth_token_configured'] == true,
    );
  }
}

class ZlcConferenceSectionModel {
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;

  ZlcConferenceSectionModel({
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
  });

  factory ZlcConferenceSectionModel.fromJson(Map<String, dynamic> json) {
    return ZlcConferenceSectionModel(
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      sectionId: (json['section_id'] as num?)?.toInt() ?? 0,
      className: json['class_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
    );
  }
}

class ZlcConferenceListItem {
  final Map<String, dynamic> conference;
  final List<ZlcConferenceSectionModel> sections;

  ZlcConferenceListItem({required this.conference, required this.sections});

  int get id => (conference['id'] as num?)?.toInt() ?? 0;
  String get title => conference['title']?.toString() ?? '';
  String get date => conference['date']?.toString() ?? '';
  String get purpose => conference['purpose']?.toString() ?? 'class';
  int get status => (conference['status'] as num?)?.toInt() ?? 0;

  factory ZlcConferenceListItem.fromJson(Map<String, dynamic> json) {
    final raw = json['conference'];
    final conf = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final secs = <ZlcConferenceSectionModel>[];
    final sl = json['sections'];
    if (sl is List) {
      for (final e in sl) {
        if (e is Map<String, dynamic>) {
          secs.add(ZlcConferenceSectionModel.fromJson(e));
        }
      }
    }
    return ZlcConferenceListItem(conference: conf, sections: secs);
  }
}

class ZlcJoinLinkModel {
  final int conferenceId;
  final String title;
  final String date;
  final int duration;
  final String password;
  final String meetingId;
  final String joinUrl;
  final String startUrl;
  final String hostDisplayName;
  final int useZoomApp;
  final int useZoomAppUser;

  ZlcJoinLinkModel({
    required this.conferenceId,
    required this.title,
    required this.date,
    required this.duration,
    required this.password,
    required this.meetingId,
    required this.joinUrl,
    required this.startUrl,
    required this.hostDisplayName,
    required this.useZoomApp,
    required this.useZoomAppUser,
  });

  factory ZlcJoinLinkModel.fromJson(Map<String, dynamic> json) {
    return ZlcJoinLinkModel(
      conferenceId: (json['conference_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      password: json['password']?.toString() ?? '',
      meetingId: json['meeting_id']?.toString() ?? '',
      joinUrl: json['join_url']?.toString() ?? '',
      startUrl: json['start_url']?.toString() ?? '',
      hostDisplayName: json['host_display_name']?.toString() ?? '',
      useZoomApp: (json['use_zoom_app'] as num?)?.toInt() ?? 0,
      useZoomAppUser: (json['use_zoom_app_user'] as num?)?.toInt() ?? 0,
    );
  }
}

class ZlcFeedbackSummaryModel {
  final int total;
  final int unread;
  final int read;
  final int critical;

  ZlcFeedbackSummaryModel({
    required this.total,
    required this.unread,
    required this.read,
    required this.critical,
  });

  factory ZlcFeedbackSummaryModel.fromJson(Map<String, dynamic> json) {
    return ZlcFeedbackSummaryModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      read: (json['read'] as num?)?.toInt() ?? 0,
      critical: (json['critical'] as num?)?.toInt() ?? 0,
    );
  }
}
