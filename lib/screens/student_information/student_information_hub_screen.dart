import 'package:flutter/material.dart';
import 'package:learining_portal/screens/student_information/si_disabled_students_screen.dart';
import 'package:learining_portal/screens/student_information/si_multiclass_screen.dart';
import 'package:learining_portal/screens/student_information/si_online_admissions_screen.dart';
import 'package:learining_portal/screens/student_information/si_reference_list_screen.dart';
import 'package:learining_portal/screens/student_information/si_student_search_screen.dart';
import 'package:learining_portal/screens/student_information/si_web_only_feature_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub matching web sidebar "Student Information" (read-focused features on mobile).
class StudentInformationHubScreen extends StatelessWidget {
  const StudentInformationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Informations'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _tile(
            context,
            icon: Icons.person_search_rounded,
            title: 'Student Details',
            subtitle: 'Search by class/section or keyword',
            builder: (_) => const SiStudentSearchScreen(),
          ),
          _tile(
            context,
            icon: Icons.category_rounded,
            title: 'Student Categories',
            subtitle: 'Reference list',
            builder: (_) => const SiReferenceListScreen(kind: SiReferenceKind.categories),
          ),
          _tile(
            context,
            icon: Icons.house_rounded,
            title: 'Student Houses',
            subtitle: 'School houses',
            builder: (_) => const SiReferenceListScreen(kind: SiReferenceKind.houses),
          ),
          _tile(
            context,
            icon: Icons.rule_folder_rounded,
            title: 'Disable Reasons',
            subtitle: 'Reasons catalogue',
            builder: (_) => const SiReferenceListScreen(kind: SiReferenceKind.reasons),
          ),
          _tile(
            context,
            icon: Icons.person_off_rounded,
            title: 'Disabled Students',
            subtitle: 'Inactive student records',
            builder: (_) => const SiDisabledStudentsScreen(),
          ),
          _tile(
            context,
            icon: Icons.copy_all_rounded,
            title: 'Multi Class Student',
            subtitle: 'Students with multiple enrollments',
            builder: (_) => const SiMulticlassScreen(),
          ),
          _tile(
            context,
            icon: Icons.cloud_upload_rounded,
            title: 'Online Admission',
            subtitle: 'Applications list',
            builder: (_) => const SiOnlineAdmissionsScreen(),
          ),
          _tile(
            context,
            icon: Icons.person_add_rounded,
            title: 'Student Admission',
            subtitle: 'Add new students (web admin)',
            builder: (_) => const SiWebOnlyFeatureScreen(
              title: 'Student Admission',
              body:
                  'Creating new student admissions uses the full web admin form (documents, fees links, custom fields). Please use the school portal in a browser for this action.',
            ),
          ),
          _tile(
            context,
            icon: Icons.delete_sweep_rounded,
            title: 'Bulk Delete',
            subtitle: 'Mass delete (web admin)',
            builder: (_) => const SiWebOnlyFeatureScreen(
              title: 'Bulk Delete',
              body:
                  'Bulk delete is restricted to the web admin panel where confirmations and audit controls apply.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accentTeal.withOpacity(0.15),
          child: Icon(icon, color: AppColors.primaryBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: builder),
          );
        },
      ),
    );
  }
}
