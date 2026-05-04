import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class CommMessageDetailScreen extends StatefulWidget {
  const CommMessageDetailScreen({super.key, required this.messageId});

  final int messageId;

  @override
  State<CommMessageDetailScreen> createState() => _CommMessageDetailScreenState();
}

class _CommMessageDetailScreenState extends State<CommMessageDetailScreen> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getMessageDetail(widget.messageId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getMessageDetail(widget.messageId);
    });
    await _future;
  }

  static String _labelForKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Message detail',
      subtitle: 'ID ${widget.messageId}',
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
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading message…');
          }
          final map = snap.data;
          if (map == null || map.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
              children: [
                const SiEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load message',
                  message: 'Check your connection or permissions.',
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _reload(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            );
          }
          final keys = map.keys.toList()..sort();
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final k in keys)
                  SiKeyValueTile(
                    label: _labelForKey(k),
                    value: map[k]?.toString() ?? '',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
