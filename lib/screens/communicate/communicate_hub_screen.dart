import 'package:flutter/material.dart';
import 'package:learining_portal/screens/communicate/comm_email_templates_screen.dart';
import 'package:learining_portal/screens/communicate/comm_messages_log_screen.dart';
import 'package:learining_portal/screens/communicate/comm_messages_scheduled_screen.dart';
import 'package:learining_portal/screens/communicate/comm_send_email_screen.dart';
import 'package:learining_portal/screens/communicate/comm_sms_templates_screen.dart';
import 'package:learining_portal/screens/student_information/si_web_only_feature_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Hub aligned with web "Communicate" (excluding Notice Board — use dashboard notice box).
class CommunicateHubScreen extends StatelessWidget {
  const CommunicateHubScreen({super.key});

  static const List<LinearGradient> _gradients = [
    LinearGradient(
      colors: [AppColors.secondaryPurple, AppColors.primaryBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.primaryBlue, AppColors.accentTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.accentTeal, AppColors.secondaryPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tiles = <_HubEntry>[
      _HubEntry(
        icon: Icons.history_rounded,
        title: 'Email / SMS Log',
        subtitle: 'Sent messages',
        gradient: _gradients[0],
        builder: (_) => const CommMessagesLogScreen(),
      ),
      _HubEntry(
        icon: Icons.schedule_rounded,
        title: 'Scheduled Messages',
        subtitle: 'Queued sends',
        gradient: _gradients[1],
        builder: (_) => const CommMessagesScheduledScreen(),
      ),
      _HubEntry(
        icon: Icons.mail_outline_rounded,
        title: 'Email Templates',
        subtitle: 'Saved email bodies',
        gradient: _gradients[2],
        builder: (_) => const CommEmailTemplatesScreen(),
      ),
      _HubEntry(
        icon: Icons.sms_outlined,
        title: 'SMS Templates',
        subtitle: 'Saved SMS texts',
        gradient: _gradients[0],
        builder: (_) => const CommSmsTemplatesScreen(),
      ),
      _HubEntry(
        icon: Icons.mark_email_read_outlined,
        title: 'Send Email',
        subtitle: 'Class, sections, or individual addresses',
        gradient: _gradients[1],
        builder: (_) => const CommSendEmailScreen(),
      ),
      _HubEntry(
        icon: Icons.send_rounded,
        title: 'Send SMS',
        subtitle: 'Compose on web admin',
        gradient: _gradients[2],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Send SMS',
          body:
              'SMS sending and gateway settings are managed in the web admin panel.',
        ),
      ),
      _HubEntry(
        icon: Icons.vpn_key_rounded,
        title: 'Login Credentials',
        subtitle: 'Bulk send on web admin',
        gradient: _gradients[0],
        builder: (_) => const SiWebOnlyFeatureScreen(
          title: 'Login Credentials',
          body:
              'Bulk sending login credentials is handled in the web admin for security and audit controls.',
        ),
      ),
    ];

    return SiThemedPageScaffold(
      title: 'Communicate',
      subtitle: 'Email, SMS & templates (notice board stays on dashboard)',
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
