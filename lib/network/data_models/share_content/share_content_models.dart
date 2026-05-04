class DcContentTypeModel {
  final int id;
  final String name;
  final String description;
  final String isActive;

  DcContentTypeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory DcContentTypeModel.fromJson(Map<String, dynamic> json) {
    return DcContentTypeModel(
      id: _i(json['id']),
      name: _s(json['name']),
      description: _s(json['description']),
      isActive: _s(json['is_active']),
    );
  }
}

class DcUploadContentModel {
  final int id;
  final int contentTypeId;
  final String contentTypeName;
  final String realName;
  final String fileType;
  final String mimeType;
  final String fileSize;
  final String vidUrl;
  final String vidTitle;
  final String dirPath;
  final String imgName;
  final String thumbPath;
  final int uploadBy;
  final String uploadedByName;
  final String createdAt;

  DcUploadContentModel({
    required this.id,
    required this.contentTypeId,
    required this.contentTypeName,
    required this.realName,
    required this.fileType,
    required this.mimeType,
    required this.fileSize,
    required this.vidUrl,
    required this.vidTitle,
    required this.dirPath,
    required this.imgName,
    required this.thumbPath,
    required this.uploadBy,
    required this.uploadedByName,
    required this.createdAt,
  });

  factory DcUploadContentModel.fromJson(Map<String, dynamic> json) {
    return DcUploadContentModel(
      id: _i(json['id']),
      contentTypeId: _i(json['content_type_id']),
      contentTypeName: _s(json['content_type_name']),
      realName: _s(json['real_name']),
      fileType: _s(json['file_type']),
      mimeType: _s(json['mime_type']),
      fileSize: _s(json['file_size']),
      vidUrl: _s(json['vid_url']),
      vidTitle: _s(json['vid_title']),
      dirPath: _s(json['dir_path']),
      imgName: _s(json['img_name']),
      thumbPath: _s(json['thumb_path']),
      uploadBy: _i(json['upload_by']),
      uploadedByName: _s(json['uploaded_by_name']),
      createdAt: _s(json['created_at']),
    );
  }
}

class DcVideoTutorialModel {
  final int id;
  final String title;
  final String vidTitle;
  final String description;
  final String thumbPath;
  final String dirPath;
  final String imgName;
  final String thumbName;
  final String videoLink;
  final int createdBy;
  final String createdByName;
  final String createdAt;

  DcVideoTutorialModel({
    required this.id,
    required this.title,
    required this.vidTitle,
    required this.description,
    required this.thumbPath,
    required this.dirPath,
    required this.imgName,
    required this.thumbName,
    required this.videoLink,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory DcVideoTutorialModel.fromJson(Map<String, dynamic> json) {
    return DcVideoTutorialModel(
      id: _i(json['id']),
      title: _s(json['title']),
      vidTitle: _s(json['vid_title']),
      description: _s(json['description']),
      thumbPath: _s(json['thumb_path']),
      dirPath: _s(json['dir_path']),
      imgName: _s(json['img_name']),
      thumbName: _s(json['thumb_name']),
      videoLink: _s(json['video_link']),
      createdBy: _i(json['created_by']),
      createdByName: _s(json['created_by_name']),
      createdAt: _s(json['created_at']),
    );
  }
}

class DcShareRoleModel {
  final int id;
  final String name;

  DcShareRoleModel({required this.id, required this.name});

  factory DcShareRoleModel.fromJson(Map<String, dynamic> json) {
    return DcShareRoleModel(
      id: _i(json['id']),
      name: _s(json['name']),
    );
  }
}

class DcShareFormMeta {
  final bool guardianOption;
  final List<DcShareRoleModel> roles;

  const DcShareFormMeta({
    required this.guardianOption,
    required this.roles,
  });
}

class DcClassSectionOptionModel {
  final int id;
  final int classId;
  final int sectionId;
  final String label;

  DcClassSectionOptionModel({
    required this.id,
    required this.classId,
    required this.sectionId,
    required this.label,
  });

  factory DcClassSectionOptionModel.fromJson(Map<String, dynamic> json) {
    return DcClassSectionOptionModel(
      id: _i(json['id']),
      classId: _i(json['class_id']),
      sectionId: _i(json['section_id']),
      label: _s(json['label']),
    );
  }
}

class DcShareContentModel {
  final int id;
  final String sendTo;
  final String title;
  final String shareDate;
  final String validUpto;
  final String description;
  final int createdBy;
  final String createdByName;
  final String employeeId;
  final String createdAt;

  DcShareContentModel({
    required this.id,
    required this.sendTo,
    required this.title,
    required this.shareDate,
    required this.validUpto,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    required this.employeeId,
    required this.createdAt,
  });

  factory DcShareContentModel.fromJson(Map<String, dynamic> json) {
    return DcShareContentModel(
      id: _i(json['id']),
      sendTo: _s(json['send_to']),
      title: _s(json['title']),
      shareDate: _s(json['share_date']),
      validUpto: _s(json['valid_upto']),
      description: _s(json['description']),
      createdBy: _i(json['created_by']),
      createdByName: _s(json['created_by_name']),
      employeeId: _s(json['employee_id']),
      createdAt: _s(json['created_at']),
    );
  }
}

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}
