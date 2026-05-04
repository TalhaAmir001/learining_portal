import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/screens/share_content/dc_urls.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class DcVideoTutorialsScreen extends StatefulWidget {
  const DcVideoTutorialsScreen({super.key});

  @override
  State<DcVideoTutorialsScreen> createState() => _DcVideoTutorialsScreenState();
}

class _DcVideoTutorialsScreenState extends State<DcVideoTutorialsScreen> {
  late Future<List<DcVideoTutorialModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShareContentRepository.getVideoTutorials();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ShareContentRepository.getVideoTutorials();
    });
    await _future;
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    var s = raw.trim();
    if (s.isEmpty) {
      SiChrome.showMessage(context, 'No video link.');
      return;
    }
    if (!dcLooksLikeHttpUrl(s)) {
      s = dcResolvePortalFileUrl('', s);
    }
    final uri = Uri.tryParse(s);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      SiChrome.showMessage(context, 'Invalid video URL.');
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      SiChrome.showMessage(context, 'Could not open link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Video tutorials',
      subtitle: 'Open in browser or player',
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
      child: FutureBuilder<List<DcVideoTutorialModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading tutorials…');
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.video_library_outlined,
              title: 'No tutorials',
              message: 'Add tutorials from the web admin.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final v = list[i];
                final title = v.title.isNotEmpty ? v.title : v.vidTitle;
                final sub = [
                  if (v.createdByName.isNotEmpty) v.createdByName,
                  if (v.createdAt.isNotEmpty) v.createdAt,
                ].join(' · ');
                return SiResultCard(
                  title: title.isNotEmpty ? title : 'Tutorial #${v.id}',
                  subtitle: sub.isNotEmpty ? sub : (v.description.isNotEmpty ? v.description : 'Tap to open'),
                  leadingIcon: Icons.play_circle_outline_rounded,
                  onTap: () => _openLink(context, v.videoLink),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
