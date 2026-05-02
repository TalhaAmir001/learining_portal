import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_online_admission_detail_screen.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Admission'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<SiOnlineAdmissionListModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No applications returned.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = list[i];
                return ListTile(
                  title: Text(
                    r.displayName.isEmpty ? 'Ref ${r.referenceNo}' : r.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ref: ${r.referenceNo}\n'
                    '${r.className}${r.className.isNotEmpty && r.sectionName.isNotEmpty ? ' — ' : ''}${r.sectionName}\n'
                    'Form: ${r.formStatus} · Enroll: ${r.isEnroll}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
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
