import 'package:flutter/material.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class WebPortalFeatureScreen extends StatelessWidget {
  const WebPortalFeatureScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.portalPath,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String portalPath;
  final String body;

  Uri get _uri => Uri.parse('${ApiClient.baseUrl}$portalPath');

  Future<void> _openPortal(BuildContext context) async {
    final uri = _uri;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the portal link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: title,
      subtitle: subtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.accentTeal.withOpacity(0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openPortal(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open in Portal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uri.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
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

