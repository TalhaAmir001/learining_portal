import 'package:flutter/material.dart';
import 'package:learining_portal/screens/student_information/si_disabled_students_screen.dart';
import 'package:learining_portal/screens/student_information/si_multiclass_screen.dart';
import 'package:learining_portal/screens/student_information/si_online_admissions_screen.dart';
import 'package:learining_portal/screens/student_information/si_reference_list_screen.dart';
import 'package:learining_portal/screens/student_information/si_student_search_screen.dart';
import 'package:learining_portal/screens/student_information/si_web_only_feature_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub matching web sidebar "Student Information" (read-focused features on mobile).
class StudentInformationHubScreen extends StatelessWidget {
  const StudentInformationHubScreen({super.key});

  static const List<LinearGradient> _gradients = [
    LinearGradient(
      colors: [AppColors.primaryBlue, AppColors.accentTeal],
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
        icon: Icons.person_search_rounded,
        title: 'Student Details',
        subtitle: 'Search by class, section, or keyword',
        gradient: _gradients[0],
        builder: (_) => const SiStudentSearchScreen(),
      ),
      _HubEntry(
        icon: Icons.category_rounded,
        title: 'Student Categories',
        subtitle: 'Reference list',
        gradient: _gradients[1],
        builder: (_) =>
            const SiReferenceListScreen(kind: SiReferenceKind.categories),
      ),
      _HubEntry(
        icon: Icons.house_rounded,
        title: 'Student Houses',
        subtitle: 'School houses',
        gradient: _gradients[2],
        builder: (_) =>
            const SiReferenceListScreen(kind: SiReferenceKind.houses),
      ),
      _HubEntry(
        icon: Icons.rule_folder_rounded,
        title: 'Disable Reasons',
        subtitle: 'Reasons catalogue',
        gradient: _gradients[0],
        builder: (_) =>
            const SiReferenceListScreen(kind: SiReferenceKind.reasons),
      ),
      _HubEntry(
        icon: Icons.person_off_rounded,
        title: 'Disabled Students',
        subtitle: 'Inactive student records',
        gradient: _gradients[1],
        builder: (_) => const SiDisabledStudentsScreen(),
      ),
      _HubEntry(
        icon: Icons.copy_all_rounded,
        title: 'Multi Class Student',
        subtitle: 'Students with multiple enrollments',
        gradient: _gradients[2],
        builder: (_) => const SiMulticlassScreen(),
      ),
      _HubEntry(
        icon: Icons.cloud_upload_rounded,
        title: 'Online Admission',
        subtitle: 'Applications list',
        gradient: _gradients[0],
        builder: (_) => const SiOnlineAdmissionsScreen(),
      ),
      _HubEntry(
        icon: Icons.person_add_rounded,
        title: 'Student Admission',
        subtitle: 'Full form on web admin',
        gradient: _gradients[1],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Student Admission',
          body:
              'Creating new student admissions uses the full web admin form (documents, fees links, custom fields). Please use the school portal in a browser for this action.',
        ),
      ),
      _HubEntry(
        icon: Icons.delete_sweep_rounded,
        title: 'Bulk Delete',
        subtitle: 'Web admin only',
        gradient: _gradients[2],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Bulk Delete',
          body:
              'Bulk delete is restricted to the web admin panel where confirmations and audit controls apply.',
        ),
      ),
    ];

    return SiThemedPageScaffold(
      title: 'Student Informations',
      subtitle: 'Registry & student directory tools',
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
