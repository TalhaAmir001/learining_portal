import 'package:flutter/material.dart';
import 'package:learining_portal/providers/auth_provider.dart' show AuthProvider, UserType;
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_admin_feedback_screen.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_join_detail_screen.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_live_classes_list_screen.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_meetings_list_screen.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_reports_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Hub: Portal 2 Conference / Zoom Live Classes parity entry.
class ZoomLiveClassesHubScreen extends StatelessWidget {
  const ZoomLiveClassesHubScreen({super.key});

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
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.userType == UserType.admin;
    final isStaff = auth.userType == UserType.admin || auth.userType == UserType.teacher;
    final isStudentFamily =
        auth.userType == UserType.student || auth.userType == UserType.guardian;

    final tiles = <Widget>[
      SiHubMenuTile(
        icon: Icons.video_camera_front_rounded,
        title: 'Live classes',
        subtitle: isStudentFamily
            ? 'Upcoming sessions for your class'
            : 'Timetable, create & manage classes',
        gradient: _gradients[0],
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const ZlcLiveClassesListScreen()),
          );
        },
      ),
      if (isStaff)
        SiHubMenuTile(
          icon: Icons.groups_2_rounded,
          title: 'Live meetings',
          subtitle: 'Staff meetings & invites',
          gradient: _gradients[1],
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ZlcMeetingsListScreen()),
            );
          },
        ),
      if (isStaff)
        SiHubMenuTile(
          icon: Icons.assessment_rounded,
          title: 'Reports & viewers',
          subtitle: 'Finished classes / meetings',
          gradient: _gradients[2],
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ZlcReportsScreen()),
            );
          },
        ),
      if (isStudentFamily)
        SiHubMenuTile(
          icon: Icons.feedback_rounded,
          title: 'Class feedback',
          subtitle: 'Rate a session you joined',
          gradient: _gradients[1],
          onTap: () async {
            final idStr = await showDialog<String>(
              context: context,
              builder: (ctx) {
                final c = TextEditingController();
                return AlertDialog(
                  title: const Text('Conference ID'),
                  content: TextField(
                    controller: c,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Enter conference id'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, c.text.trim()),
                      child: const Text('Open'),
                    ),
                  ],
                );
              },
            );
            final id = int.tryParse(idStr ?? '');
            if (id != null && id > 0 && context.mounted) {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ZlcJoinDetailScreen(conferenceId: id, openFeedbackAfter: true),
                ),
              );
            }
          },
        ),
      if (isAdmin)
        SiHubMenuTile(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Live class feedback (admin)',
          subtitle: 'Unread / critical dashboard',
          gradient: _gradients[0],
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ZlcAdminFeedbackScreen()),
            );
          },
        ),
    ];

    return SiThemedPageScaffold(
      title: 'Zoom Live Classes',
      subtitle: 'Join sessions in the Zoom app',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: tiles,
      ),
    );
  }
}
