import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/communicate/comm_message_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class CommMessagesScheduledScreen extends StatefulWidget {
  const CommMessagesScheduledScreen({super.key});

  @override
  State<CommMessagesScheduledScreen> createState() => _CommMessagesScheduledScreenState();
}

class _CommMessagesScheduledScreenState extends State<CommMessagesScheduledScreen> {
  late Future<List<CommMessageListModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getScheduledMessages();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getScheduledMessages();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Scheduled messages',
      subtitle: 'Upcoming sends',
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
            return const SiLoadingBlock(message: 'Loading schedule…');
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled',
              message: 'Scheduled rows from the web admin appear here.',
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
                final sub = m.logCardSubtitle;
                return SiResultCard(
                  title: m.title.isNotEmpty ? m.title : 'Message #${m.id}',
                  subtitle: sub.isNotEmpty ? sub : '—',
                  leadingIcon: Icons.schedule_rounded,
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
