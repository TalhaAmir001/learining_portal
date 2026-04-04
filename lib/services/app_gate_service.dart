import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Result of [sch_settings.staff_barcode] gate (1 = app may run, 0 = blocked).
enum StaffBarcodeGateResult {
  /// staff_barcode == 1
  allowed,

  /// staff_barcode == 0
  denied,

  /// Network / parse / server error
  error,
}

/// Reads `staff_barcode` from [sch_settings] via mobile API before auth.
class AppGateService {
  AppGateService._();

  static const String _endpoint = '/mobile_apis/get_sch_settings_staff_barcode.php';

  static Future<StaffBarcodeGateResult> checkStaffBarcodeGate() async {
    try {
      final response = await ApiClient.get(endpoint: _endpoint);
      if (response['success'] == true && response['staff_barcode'] != null) {
        final v = (response['staff_barcode'] as num).toInt();
        if (v == 1) return StaffBarcodeGateResult.allowed;
        return StaffBarcodeGateResult.denied;
      }
      if (kDebugMode) {
        debugPrint(
          'AppGateService: unexpected response: $response',
        );
      }
      return StaffBarcodeGateResult.error;
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('AppGateService: ApiException: $e');
      }
      return StaffBarcodeGateResult.error;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppGateService: $e');
      }
      return StaffBarcodeGateResult.error;
    }
  }
}
