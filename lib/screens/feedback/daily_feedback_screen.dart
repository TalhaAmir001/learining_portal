import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/daily_feedback/daily_feedback_provider.dart';
import 'package:learining_portal/screens/feedback/daily_feedback_form_screen.dart';
import 'package:learining_portal/screens/feedback/voice_player_widget.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyFeedbackScreen extends StatefulWidget {
  const DailyFeedbackScreen({super.key});

  @override
  State<DailyFeedbackScreen> createState() => _DailyFeedbackScreenState();
}

class _DailyFeedbackScreenState extends State<DailyFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final staffId = context.read<AuthProvider>().currentUser?.uid;
      context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
    });
  }

  void _openForm() async {
    final provider = context.read<DailyFeedbackProvider>();
    final today = provider.todayFeedback;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DailyFeedbackFormScreen(
          feedbackId: today?.id,
          existingFeedback: today,
        ),
      ),
    );
    if (result == true && mounted) {
      final staffId = context.read<AuthProvider>().currentUser?.uid;
      context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
    }
  }

  Future<void> _onRefresh() async {
    final staffId = context.read<AuthProvider>().currentUser?.uid;
    await context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
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
              _buildAppBar(context),
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
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
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
                                _buildAddFeedbackButton(
                                  context,
                                  theme,
                                  provider,
                                ),
                                const SizedBox(height: 24),
                                _buildPastFeedbacksHeader(theme, provider),
                                const SizedBox(height: 12),
                                _buildPastFeedbacksList(
                                  context,
                                  theme,
                                  provider,
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

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _buildAddFeedbackButton(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    final today = provider.todayFeedback;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openForm,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  today != null ? Icons.edit_note_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today != null ? "Edit today's feedback" : 'New feedback',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today != null
                          ? 'Update your daily feedback'
                          : 'Add message, voice & attachments',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastFeedbacksHeader(
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    final feedbacks = provider.feedbacks;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Past feedbacks',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (feedbacks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${feedbacks.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.accentTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPastFeedbacksList(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    if (provider.loadingFeedbacks) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
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
        ),
      );
    }
    if (provider.feedbacks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No feedbacks yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Your saved feedbacks will appear here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }
    final feedbacks = provider.feedbacks;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feedbacks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _FeedbackCard(model: feedbacks[index]);
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final DailyFeedbackModel model;

  const _FeedbackCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = model.createdAt;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.backgroundLight.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.secondaryPurple.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (createdAt != null && createdAt.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.08),
                      AppColors.secondaryPurple.withOpacity(0.06),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      createdAt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((model.className != null &&
                          model.className!.isNotEmpty) ||
                      (model.sectionName != null &&
                          model.sectionName!.isNotEmpty)) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (model.className != null &&
                            model.className!.isNotEmpty)
                          Chip(
                            avatar: Icon(
                              Icons.school_rounded,
                              size: 16,
                              color: AppColors.primaryBlue,
                            ),
                            label: Text(
                              model.className!,
                              style: theme.textTheme.bodySmall,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (model.sectionName != null &&
                            model.sectionName!.isNotEmpty)
                          Chip(
                            avatar: Icon(
                              Icons.group_rounded,
                              size: 16,
                              color: AppColors.secondaryPurple,
                            ),
                            label: Text(
                              model.sectionName!,
                              style: theme.textTheme.bodySmall,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (model.recipientStudentIds.isNotEmpty)
                          Text(
                            '${model.recipientStudentIds.length} student(s)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
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
                      child: VoicePlayerWidget(audioUrl: model.voiceUrl!),
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
        onTap: () => _openUrl(url),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
