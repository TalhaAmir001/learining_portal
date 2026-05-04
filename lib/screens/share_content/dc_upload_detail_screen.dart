import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/screens/share_content/dc_create_share_screen.dart';
import 'package:learining_portal/screens/share_content/dc_urls.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class DcUploadDetailScreen extends StatelessWidget {
  const DcUploadDetailScreen({super.key, required this.item});

  final DcUploadContentModel item;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      SiChrome.showMessage(context, 'No valid link for this item.');
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
    final fileUrl = item.vidUrl.trim().isNotEmpty
        ? (dcLooksLikeHttpUrl(item.vidUrl)
            ? item.vidUrl.trim()
            : dcResolvePortalFileUrl(item.dirPath, item.vidUrl))
        : dcResolvePortalFileUrl(item.dirPath, item.realName);

    return SiThemedPageScaffold(
      title: 'Content detail',
      subtitle: item.contentTypeName,
      actions: [
        IconButton(
          tooltip: 'Share this file',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DcCreateShareScreen(initialUploadIds: [item.id]),
              ),
            );
          },
          icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
        ),
        if (fileUrl.isNotEmpty)
          IconButton(
            tooltip: 'Open file',
            onPressed: () => _openUrl(context, fileUrl),
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (fileUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => _openUrl(context, fileUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Open / download'),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DcCreateShareScreen(initialUploadIds: [item.id]),
                ),
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share this file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          SiKeyValueTile(label: 'File name', value: item.realName),
          SiKeyValueTile(label: 'Content type', value: item.contentTypeName),
          SiKeyValueTile(label: 'MIME type', value: item.mimeType),
          SiKeyValueTile(label: 'File type', value: item.fileType),
          SiKeyValueTile(label: 'Size', value: item.fileSize),
          SiKeyValueTile(label: 'Uploaded by', value: item.uploadedByName),
          SiKeyValueTile(label: 'Created', value: item.createdAt),
          if (item.vidTitle.isNotEmpty)
            SiKeyValueTile(label: 'Video title', value: item.vidTitle),
          if (item.dirPath.isNotEmpty)
            SiKeyValueTile(label: 'Directory', value: item.dirPath),
          if (fileUrl.isNotEmpty) SiKeyValueTile(label: 'Resolved URL', value: fileUrl),
        ],
      ),
    );
  }
}
