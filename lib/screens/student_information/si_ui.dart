import 'package:learining_portal/utils/api_client.dart';

class SiUi {
  SiUi._();

  static String? studentImageUrl(String? imageFile) {
    if (imageFile == null || imageFile.isEmpty) return null;
    if (imageFile.startsWith('http://') || imageFile.startsWith('https://')) {
      return imageFile;
    }
    return '${ApiClient.baseUrl}/uploads/student_images/$imageFile';
  }

  static String? onlineAdmissionImageUrl(String? imageFile) {
    if (imageFile == null || imageFile.isEmpty) return null;
    if (imageFile.startsWith('http://') || imageFile.startsWith('https://')) {
      return imageFile;
    }
    return '${ApiClient.baseUrl}/uploads/student_images/$imageFile';
  }
}
