import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/communicate/comm_message_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class CommMessagesLogScreen extends StatefulWidget {
  const CommMessagesLogScreen({super.key});

  @override
  State<CommMessagesLogScreen> createState() => _CommMessagesLogScreenState();
}

class _CommMessagesLogScreenState extends State<CommMessagesLogScreen> {
  late Future<List<CommMessageListModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getMessagesLog();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getMessagesLog();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Email / SMS log',
      subtitle: 'Recent sends',
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
      child: FutureBuilder<List<CommMessageListModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading log…');
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.mark_email_unread_outlined,
              title: 'No messages',
              message: 'Sent items will appear here.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[i];
                final sub = [
                  if (m.sendThrough.isNotEmpty) m.sendThrough,
                  if (m.sendTo.isNotEmpty) m.sendTo,
                  m.preview,
                ].where((e) => e.isNotEmpty).join('\n');
                return SiResultCard(
                  title: m.title.isNotEmpty ? m.title : 'Message #${m.id}',
                  subtitle: sub.isNotEmpty ? sub : '—',
                  leadingIcon: m.sendThrough.toLowerCase().contains('sms')
                      ? Icons.sms_outlined
                      : Icons.email_outlined,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CommMessageDetailScreen(messageId: m.id),
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
