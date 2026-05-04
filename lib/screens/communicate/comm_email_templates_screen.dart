import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/communicate/comm_template_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class CommEmailTemplatesScreen extends StatefulWidget {
  const CommEmailTemplatesScreen({super.key});

  @override
  State<CommEmailTemplatesScreen> createState() => _CommEmailTemplatesScreenState();
}

class _CommEmailTemplatesScreenState extends State<CommEmailTemplatesScreen> {
  late Future<List<CommTemplateModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getEmailTemplates();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getEmailTemplates();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Email templates',
      subtitle: 'Read-only on mobile',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _reload();
            if (context.mounted) SiChrome.showMessage(context, 'Refreshed');
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
      child: FutureBuilder<List<CommTemplateModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading templates…');
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.mail_outline_rounded,
              title: 'No email templates',
              message: 'Create templates in the web admin.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final preview = t.message.trim();
                final sub = preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;
                return SiResultCard(
                  title: t.title.isNotEmpty ? t.title : 'Template #${t.id}',
                  subtitle: sub.isNotEmpty ? sub : (t.createdAt.isNotEmpty ? t.createdAt : 'Tap for full body'),
                  leadingIcon: Icons.description_outlined,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CommTemplateDetailScreen(
                          title: 'Email template',
                          template: t,
                        ),
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
