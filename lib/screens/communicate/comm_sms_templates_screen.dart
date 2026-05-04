import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/communicate/comm_template_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class CommSmsTemplatesScreen extends StatefulWidget {
  const CommSmsTemplatesScreen({super.key});

  @override
  State<CommSmsTemplatesScreen> createState() => _CommSmsTemplatesScreenState();
}

class _CommSmsTemplatesScreenState extends State<CommSmsTemplatesScreen> {
  late Future<List<CommTemplateModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getSmsTemplates();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getSmsTemplates();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'SMS templates',
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
              icon: Icons.sms_outlined,
              title: 'No SMS templates',
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
                final sub = preview.length > 100 ? '${preview.substring(0, 100)}…' : preview;
                return SiResultCard(
                  title: t.title.isNotEmpty ? t.title : 'Template #${t.id}',
                  subtitle: sub.isNotEmpty ? sub : (t.createdAt.isNotEmpty ? t.createdAt : 'Tap for full text'),
                  leadingIcon: Icons.chat_bubble_outline_rounded,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CommTemplateDetailScreen(
                          title: 'SMS template',
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
