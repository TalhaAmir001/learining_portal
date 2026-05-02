import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for Student Information mobile APIs (admin parity with web submenu).
class StudentInformationRepository {
  static Future<List<SiClassModel>> getClasses() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_classes.php',
      );
      if (response['success'] == true && response['classes'] != null) {
        final list = response['classes'] as List<dynamic>;
        return list
            .map((e) => SiClassModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getClasses: ${e.message}');
      return [];
    }
  }

  static Future<List<SiSectionModel>> getSections({int? classId}) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_sections.php',
        queryParameters: classId != null && classId > 0
            ? {'class_id': classId.toString()}
            : null,
      );
      if (response['success'] == true && response['sections'] != null) {
        final list = response['sections'] as List<dynamic>;
        return list
            .map((e) => SiSectionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getSections: ${e.message}');
      return [];
    }
  }

  /// Active students: class/section filter (section 0 = all sections in class).
  static Future<List<SiStudentRowModel>> searchStudentsByClassSection({
    required int classId,
    int sectionId = 0,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_students_search.php',
        queryParameters: {
          'mode': 'filter',
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) => SiStudentRowModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository searchStudentsByClassSection: ${e.message}');
      return [];
    }
  }

  static Future<List<SiStudentRowModel>> searchStudentsFullText({
    required String searchText,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_students_search.php',
        queryParameters: {
          'mode': 'full',
          'search_text': searchText,
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) => SiStudentRowModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository searchStudentsFullText: ${e.message}');
      return [];
    }
  }

  static Future<SiStudentDetailModel?> getStudentDetail(int studentId) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_student_detail.php',
        queryParameters: {'student_id': studentId.toString()},
      );
      if (response['success'] == true && response['student'] != null) {
        return SiStudentDetailModel.fromJson(
          response['student'] as Map<String, dynamic>,
        );
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getStudentDetail: ${e.message}');
      return null;
    }
  }

  static Future<List<SiCategoryModel>> getCategories() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_student_categories.php',
      );
      if (response['success'] == true && response['categories'] != null) {
        final list = response['categories'] as List<dynamic>;
        return list
            .map((e) => SiCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getCategories: ${e.message}');
      return [];
    }
  }

  static Future<List<SiSchoolHouseModel>> getSchoolHouses() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_school_houses.php',
      );
      if (response['success'] == true && response['houses'] != null) {
        final list = response['houses'] as List<dynamic>;
        return list
            .map((e) => SiSchoolHouseModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getSchoolHouses: ${e.message}');
      return [];
    }
  }

  static Future<List<SiDisableReasonModel>> getDisableReasons() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_disable_reasons.php',
      );
      if (response['success'] == true && response['reasons'] != null) {
        final list = response['reasons'] as List<dynamic>;
        return list
            .map((e) => SiDisableReasonModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getDisableReasons: ${e.message}');
      return [];
    }
  }

  static Future<List<SiDisabledStudentRowModel>> getDisabledStudentsByClassSection({
    required int classId,
    int sectionId = 0,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_disabled_students.php',
        queryParameters: {
          'mode': 'filter',
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) =>
                SiDisabledStudentRowModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint(
        'StudentInformationRepository getDisabledStudentsByClassSection: ${e.message}',
      );
      return [];
    }
  }

  static Future<List<SiDisabledStudentRowModel>> searchDisabledStudentsFullText({
    required String searchText,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_disabled_students.php',
        queryParameters: {
          'mode': 'full',
          'search_text': searchText,
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) =>
                SiDisabledStudentRowModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint(
        'StudentInformationRepository searchDisabledStudentsFullText: ${e.message}',
      );
      return [];
    }
  }

  static Future<List<SiMulticlassStudentModel>> getMulticlassStudents({
    required int classId,
    required int sectionId,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_multiclass_students.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) =>
                SiMulticlassStudentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getMulticlassStudents: ${e.message}');
      return [];
    }
  }

  static Future<List<SiOnlineAdmissionListModel>> getOnlineAdmissions({
    int limit = 200,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_online_admissions.php',
        queryParameters: {'limit': limit.toString()},
      );
      if (response['success'] == true && response['applications'] != null) {
        final list = response['applications'] as List<dynamic>;
        return list
            .map((e) => SiOnlineAdmissionListModel.fromJson(
                  e as Map<String, dynamic>,
                ))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('StudentInformationRepository getOnlineAdmissions: ${e.message}');
      return [];
    }
  }

  /// Raw map for detail screen (all columns from API minus secrets).
  static Future<Map<String, dynamic>?> getOnlineAdmissionDetail(int id) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_si_online_admission_detail.php',
        queryParameters: {'id': id.toString()},
      );
      if (response['success'] == true && response['application'] != null) {
        return Map<String, dynamic>.from(
          response['application'] as Map<String, dynamic>,
        );
      }
      return null;
    } on ApiException catch (e) {
      debugPrint(
        'StudentInformationRepository getOnlineAdmissionDetail: ${e.message}',
      );
      return null;
    }
  }
}
