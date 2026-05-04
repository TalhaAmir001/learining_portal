import 'package:flutter/material.dart';
import 'package:learining_portal/screens/share_content/dc_create_share_screen.dart';
import 'package:learining_portal/screens/share_content/dc_content_types_screen.dart';
import 'package:learining_portal/screens/share_content/dc_share_contents_screen.dart';
import 'package:learining_portal/screens/share_content/dc_upload_contents_screen.dart';
import 'package:learining_portal/screens/share_content/dc_upload_content_screen.dart';
import 'package:learining_portal/screens/share_content/dc_video_tutorials_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub aligned with web "Share Content" / Download Center.
class ShareContentHubScreen extends StatelessWidget {
  const ShareContentHubScreen({super.key});

  static const List<LinearGradient> _gradients = [
    LinearGradient(
      colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.secondaryPurple, AppColors.accentTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.accentTeal, AppColors.primaryBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tiles = <_HubEntry>[
      _HubEntry(
        icon: Icons.folder_shared_rounded,
        title: 'Content Library',
        subtitle: 'Uploaded files & media',
        gradient: _gradients[0],
        builder: (_) => const DcUploadContentsScreen(),
      ),
      _HubEntry(
        icon: Icons.share_rounded,
        title: 'Share with users',
        subtitle: 'Public link, groups, classes, or individuals',
        gradient: _gradients[1],
        builder: (_) => const DcCreateShareScreen(),
      ),
      _HubEntry(
        icon: Icons.label_outline_rounded,
        title: 'Content Types',
        subtitle: 'Categories for uploads',
        gradient: _gradients[2],
        builder: (_) => const DcContentTypesScreen(),
      ),
      _HubEntry(
        icon: Icons.play_circle_outline_rounded,
        title: 'Video Tutorials',
        subtitle: 'Guidance videos',
        gradient: _gradients[0],
        builder: (_) => const DcVideoTutorialsScreen(),
      ),
      _HubEntry(
        icon: Icons.ios_share_rounded,
        title: 'Shared Content',
        subtitle: 'Batches shared with groups',
        gradient: _gradients[1],
        builder: (_) => const DcShareContentsScreen(),
      ),
      _HubEntry(
        icon: Icons.cloud_upload_rounded,
        title: 'Upload Content',
        subtitle: 'Pick a file and send to the library',
        gradient: _gradients[2],
        builder: (_) => const DcUploadContentScreen(),
      ),
    ];

    return SiThemedPageScaffold(
      title: 'Share Content',
      subtitle: 'Download center & shared materials',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        itemCount: tiles.length,
        itemBuilder: (context, index) {
          final t = tiles[index];
          return SiHubMenuTile(
            icon: t.icon,
            title: t.title,
            subtitle: t.subtitle,
            gradient: t.gradient,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: t.builder),
              );
            },
          );
        },
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final WidgetBuilder builder;
}
