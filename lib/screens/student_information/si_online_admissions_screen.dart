import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_online_admission_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiOnlineAdmissionsScreen extends StatefulWidget {
  const SiOnlineAdmissionsScreen({super.key});

  @override
  State<SiOnlineAdmissionsScreen> createState() => _SiOnlineAdmissionsScreenState();
}

class _SiOnlineAdmissionsScreenState extends State<SiOnlineAdmissionsScreen> {
  late Future<List<SiOnlineAdmissionListModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = StudentInformationRepository.getOnlineAdmissions();
  }

  Future<void> _reload() async {
    setState(() {
      _future = StudentInformationRepository.getOnlineAdmissions();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Online Admission',
      subtitle: 'Recent applications from the portal',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _reload,
        ),
      ],
      child: FutureBuilder<List<SiOnlineAdmissionListModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SiLoadingBlock(message: 'Loading applications…');
          }
          if (snap.hasError) {
            return SiEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: snap.error.toString(),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return SiEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No applications',
              message: 'No online admission records were returned from the server.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                final title = r.displayName.isEmpty
                    ? 'Ref ${r.referenceNo}'
                    : r.displayName;
                final subtitle =
                    'Ref: ${r.referenceNo}\n'
                    '${r.className}${r.className.isNotEmpty && r.sectionName.isNotEmpty ? ' — ' : ''}${r.sectionName}\n'
                    'Form: ${r.formStatus} · Enroll: ${r.isEnroll}';
                return SiResultCard(
                  title: title,
                  subtitle: subtitle,
                  leadingIcon: Icons.article_rounded,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SiOnlineAdmissionDetailScreen(id: r.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
