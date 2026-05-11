import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/smart_monitoring/smart_monitoring_models.dart';

/// Shared color palette for the Smart Monitoring screens — keeps the
/// traffic-light treatment between the index list, the per-student report
/// and the chart helpers in sync.
abstract final class SmartMonitoringPalette {
  // Same hex values as the web index/report views (text-success/warning/danger).
  static const Color good = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color critical = Color(0xFFDC2626);
  static const Color neutral = Color(0xFF94A3B8);

  /// Status -> color mapping.
  static Color statusColor(SmartMonitoringStatus status) {
    switch (status) {
      case SmartMonitoringStatus.good:
        return good;
      case SmartMonitoringStatus.warning:
        return warning;
      case SmartMonitoringStatus.critical:
        return critical;
    }
  }

  /// Mirror of `sm_report_color_for_pct()` in report.php — picks a colour for
  /// 0–100 metric values so charts and progress bars use the same ramp.
  static Color colorForPct(double? value) {
    if (value == null) return neutral;
    if (value >= 80) return const Color(0xFF16A34A);
    if (value >= 65) return const Color(0xFF65A30D);
    if (value >= 50) return const Color(0xFFCA8A04);
    if (value >= 40) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }
}
