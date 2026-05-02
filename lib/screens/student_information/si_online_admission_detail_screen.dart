import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiOnlineAdmissionDetailScreen extends StatelessWidget {
  const SiOnlineAdmissionDetailScreen({super.key, required this.id});

  final int id;

  static const _skipKeys = <String>{
    'password',
    'user_password',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Application #$id'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: StudentInformationRepository.getOnlineAdmissionDetail(id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final map = snap.data;
          if (map == null || map.isEmpty) {
            return const Center(child: Text('Could not load application.'));
          }
          final entries = map.entries.where((e) {
            if (_skipKeys.contains(e.key)) return false;
            final v = e.value;
            if (v == null) return false;
            if (v is String && v.trim().isEmpty) return false;
            if (v is! String && v is! num && v is! bool) return false;
            return true;
          }).toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    e.value.toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
