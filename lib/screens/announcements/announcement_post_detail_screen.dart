import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/announcement/announcement_models.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementPostDetailScreen extends StatelessWidget {
  const AnnouncementPostDetailScreen({super.key, required this.post});

  final AnnouncementPost post;

  Uri? get _mediaUri {
    final path = post.mediaPath.trim();
    if (path.isEmpty) return null;
    final base = ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base/$p');
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    SiChrome.showMessage(context, 'Could not open the link.');
  }

  @override
  Widget build(BuildContext context) {
    final title = post.title.isNotEmpty ? post.title : 'Announcement';
    final subtitle = post.authorName;

    return SiThemedPageScaffold(
      title: title,
      subtitle: subtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.mediaType == 'image' && _mediaUri != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _mediaUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.backgroundLight,
                      child: const Center(
                        child: Text('Could not load image'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              elevation: 0,
              color: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (post.body.isNotEmpty)
                      Text(
                        post.body,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                      )
                    else
                      Text(
                        'No content.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    if (post.mediaType == 'video_embed' && post.embedUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openUrl(context, Uri.parse(post.embedUrl)),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Watch video'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    if (post.mediaType == 'video_upload' && _mediaUri != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openUrl(context, _mediaUri!),
                        icon: const Icon(Icons.ondemand_video_rounded),
                        label: const Text('Open video'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mediaUri.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

