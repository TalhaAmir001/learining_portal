import 'package:flutter/material.dart';
import 'package:learining_portal/screens/academics/ac_class_timetable_screen.dart';
import 'package:learining_portal/screens/academics/ac_teacher_timetable_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_assign_class_teacher_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_classes_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_promote_students_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_sections_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_subject_groups_screen.dart';
import 'package:learining_portal/screens/academics/admin/admin_subjects_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub: Academics (Admin sidebar parity).
///
/// Per current requirements this contains only:
/// - Class timetable
/// - Teacher timetable
/// - Assign Class Teacher
/// - Promote Students
/// - Subject Group
/// - Subjects
/// - Class
/// - Sections
class AcademicsHubScreen extends StatelessWidget {
  const AcademicsHubScreen({super.key});

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
        title: 'Class timetable',
        subtitle: 'By class & section — daily or weekly',
        gradient: _gradients[0],
        builder: (_) => const AcClassTimetableScreen(),
      ),
      _HubEntry(
        icon: Icons.person_rounded,
        title: 'Teacher timetable',
        subtitle: 'Your periods, or pick a teacher (admin)',
        gradient: _gradients[1],
        builder: (_) => const AcTeacherTimetableScreen(),
      ),
      _HubEntry(
        icon: Icons.supervisor_account_rounded,
        title: 'Assign Class Teacher',
        subtitle: 'Assign teacher to class & section',
        gradient: _gradients[2],
        builder: (_) => const AdminAssignClassTeacherScreen(),
      ),
      _HubEntry(
        icon: Icons.trending_up_rounded,
        title: 'Promote Students',
        subtitle: 'Move students to the next session',
        gradient: _gradients[0],
        builder: (_) => const AdminPromoteStudentsScreen(),
      ),
      _HubEntry(
        icon: Icons.grid_view_rounded,
        title: 'Subject Group',
        subtitle: 'Manage subject groups',
        gradient: _gradients[1],
        builder: (_) => const AdminSubjectGroupsScreen(),
      ),
      _HubEntry(
        icon: Icons.menu_book_rounded,
        title: 'Subjects',
        subtitle: 'Manage subject list',
        gradient: _gradients[2],
        builder: (_) => const AdminSubjectsScreen(),
      ),
      _HubEntry(
        icon: Icons.class_rounded,
        title: 'Class',
        subtitle: 'Manage classes',
        gradient: _gradients[0],
        builder: (_) => const AdminClassesScreen(),
      ),
      _HubEntry(
        icon: Icons.view_list_rounded,
        title: 'Sections',
        subtitle: 'Manage sections',
        gradient: _gradients[1],
        builder: (_) => const AdminSectionsScreen(),
      ),
    ];

    return SiThemedPageScaffold(
      title: 'Academics',
      subtitle: 'Admin',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: tiles.length,
        itemBuilder: (context, i) {
          final t = tiles[i];
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
  _HubEntry({
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
