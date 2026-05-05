import 'package:flutter/material.dart';
import 'package:learining_portal/screens/attendance/at_staff_day_screen.dart';
import 'package:learining_portal/screens/attendance/at_student_day_screen.dart';
import 'package:learining_portal/screens/attendance/at_subject_matrix_screen.dart';
import 'package:learining_portal/screens/attendance/at_subject_period_screen.dart';
import 'package:learining_portal/screens/student_information/si_web_only_feature_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub aligned with Portal 2 admin sidebar: Attendance (student day, period, staff) + matrix report.
class AttendanceHubScreen extends StatelessWidget {
  const AttendanceHubScreen({super.key});

  /// Same rotation as Share Content hub (primary → purple → teal).
  static const List<LinearGradient> _gradients = [
    LinearGradient(
      colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.secondaryPurple, AppColors.accentTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.accentTeal, AppColors.primaryBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tiles = <_HubEntry>[
      _HubEntry(
        icon: Icons.groups_rounded,
        title: 'Student attendance',
        subtitle: 'Daily register by class & section',
        gradient: _gradients[0],
        builder: (_) => const AtStudentDayScreen(),
      ),
      _HubEntry(
        icon: Icons.schedule_rounded,
        title: 'Period attendance',
        subtitle: 'Mark by subject timetable slot',
        gradient: _gradients[1],
        builder: (_) => const AtSubjectPeriodScreen(),
      ),
      _HubEntry(
        icon: Icons.badge_rounded,
        title: 'Staff attendance',
        subtitle: 'By role (Teacher, Admin, …)',
        gradient: _gradients[2],
        builder: (_) => const AtStaffDayScreen(),
      ),
      _HubEntry(
        icon: Icons.grid_view_rounded,
        title: 'Period attendance matrix',
        subtitle: 'Read-only grid for one day',
        gradient: _gradients[0],
        builder: (_) => const AtSubjectMatrixScreen(),
      ),
      _HubEntry(
        icon: Icons.settings_suggest_rounded,
        title: 'Attendance settings',
        subtitle: 'Class times & biometric (web)',
        gradient: _gradients[1],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Attendance settings',
          body:
              'Auto-submit times, class-section attendance windows, and biometric/QR options are configured in the web admin (Attendance → settings). The app saves marks using the same database tables as the portal.',
        ),
      ),
      _HubEntry(
        icon: Icons.picture_as_pdf_rounded,
        title: 'PDF / payroll reports',
        subtitle: 'Extended reports on web',
        gradient: _gradients[2],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Reports',
          body:
              'Class attendance reports, staff day-wise exports, payroll-linked summaries, and daily attendance PDFs are available in the web admin under Reports → Attendance.',
        ),
      ),
    ];

    return SiThemedPageScaffold(
      title: 'Attendance',
      subtitle: 'Student, period, and staff registers',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        itemCount: tiles.length,
        itemBuilder: (context, index) {
          final t = tiles[index];
          return SiHubMenuTile(
            icon: t.icon,
            title: t.title,
            subtitle: t.subtitle,
            gradient: t.gradient,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: t.builder),
              );
            },
          );
        },
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final WidgetBuilder builder;
}
