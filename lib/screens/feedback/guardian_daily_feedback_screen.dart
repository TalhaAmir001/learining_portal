import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/network/domain/daily_feedback_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/daily_feedback/daily_feedback_provider.dart';
import 'package:learining_portal/screens/feedback/voice_player_widget.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for guardian/parent: shows all daily feedbacks for their children.
class GuardianDailyFeedbackScreen extends StatefulWidget {
  const GuardianDailyFeedbackScreen({super.key});

  @override
  State<GuardianDailyFeedbackScreen> createState() =>
      _GuardianDailyFeedbackScreenState();
}

class _GuardianDailyFeedbackScreenState
    extends State<GuardianDailyFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parentId = context.read<AuthProvider>().currentUser?.id;
      context.read<DailyFeedbackProvider>().loadFeedbacksForGuardian(parentId);
    });
  }

  Future<void> _onRefresh() async {
    final parentId = context.read<AuthProvider>().currentUser?.id;
    await context.read<DailyFeedbackProvider>().loadFeedbacksForGuardian(parentId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryPurple,
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.25, 0.4],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context, theme),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Consumer<DailyFeedbackProvider>(
                      builder: (context, provider, _) {
                        if (provider.loadingFeedbacks) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.accentTeal,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading feedbacks...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (provider.feedbacks.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            color: AppColors.primaryBlue,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              child: SizedBox(
                                height: 400,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.feedback_outlined,
                                        size: 56,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No feedback yet',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Feedback from teachers for your child(ren) will appear here',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppColors.primaryBlue,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Feedback for your child(ren)',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${provider.feedbacks.length} feedback(s)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...provider.feedbacks.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _GuardianFeedbackCard(
                                      model: f,
                                      parentId: context.read<AuthProvider>().currentUser?.id,
                                      onVoicePlayed: _onRefresh,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.feedback_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Daily Feedback',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianFeedbackCard extends StatelessWidget {
  final DailyFeedbackModel model;
  final String? parentId;
  final VoidCallback? onVoicePlayed;

  const _GuardianFeedbackCard({
    required this.model,
    this.parentId,
    this.onVoicePlayed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = model.createdAt;
    final studentNames = model.recipientChildNames;
    final hasNames = studentNames.isNotEmpty;
    final classSection = [
      if (model.className != null && model.className!.isNotEmpty)
        model.className,
      if (model.sectionName != null && model.sectionName!.isNotEmpty)
        model.sectionName,
    ].join(' • ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (createdAt != null && createdAt.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          createdAt,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (hasNames) ...[
                  if (createdAt != null && createdAt.isNotEmpty)
                    const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          studentNames.join(', '),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (classSection.isNotEmpty) ...[
                  if (hasNames || (createdAt != null && createdAt.isNotEmpty))
                    const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 14,
                        color: AppColors.accentTeal,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          classSection,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.accentTeal,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.messageText != null &&
                    model.messageText!.isNotEmpty) ...[
                  Text(
                    model.messageText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (model.voiceUrl != null || model.attachments.isNotEmpty)
                    const SizedBox(height: 12),
                ],
                if (model.voiceUrl != null && model.voiceUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (model.voicePlayedByParent)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.accentTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Voice played',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        VoicePlayerWidget(
                          audioUrl: model.voiceUrl!,
                          onPlayStarted: parentId != null
                              ? () async {
                                  await DailyFeedbackRepository.markFeedbackVoicePlayed(
                                    feedbackId: model.id,
                                    parentId: parentId!,
                                  );
                                  onVoicePlayed?.call();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                if (model.attachments.isNotEmpty) ...[
                  if (model.voiceUrl != null && model.voiceUrl!.isNotEmpty)
                    const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: model.attachments.map((a) {
                      return _LinkChip(
                        icon: Icons.attach_file_rounded,
                        label: a.filename ?? 'Attachment',
                        url: a.fileUrl,
                        color: AppColors.secondaryPurple,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  const _LinkChip({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
