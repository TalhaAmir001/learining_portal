import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

class SiOnlineAdmissionDetailScreen extends StatelessWidget {
  const SiOnlineAdmissionDetailScreen({super.key, required this.id});

  final int id;

  static const _skipKeys = <String>{
    'password',
    'user_password',
  };

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Application',
      subtitle: 'Reference #$id',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: StudentInformationRepository.getOnlineAdmissionDetail(id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SiLoadingBlock(message: 'Loading application…');
          }
          final map = snap.data;
          if (map == null || map.isEmpty) {
            return SiEmptyState(
              icon: Icons.description_outlined,
              title: 'Not found',
              message: 'Could not load this application.',
            );
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return SiKeyValueTile(
                label: e.key,
                value: e.value.toString(),
              );
            },
          );
        },
      ),
    );
  }
}
