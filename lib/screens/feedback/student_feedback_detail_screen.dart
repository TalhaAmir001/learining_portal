import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/daily_feedback/daily_feedback_provider.dart';
import 'package:learining_portal/screens/feedback/daily_feedback_form_screen.dart';
import 'package:learining_portal/screens/feedback/voice_player_widget.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows feedback for a single student. Date defaults to today; user can pick another date.
class StudentFeedbackDetailScreen extends StatefulWidget {
  final FeedbackStudentModel student;
  final int classId;
  final int sectionId;

  const StudentFeedbackDetailScreen({
    super.key,
    required this.student,
    required this.classId,
    required this.sectionId,
  });

  @override
  State<StudentFeedbackDetailScreen> createState() => _StudentFeedbackDetailScreenState();
}

class _StudentFeedbackDetailScreenState extends State<StudentFeedbackDetailScreen> {
  DateTime _selectedDate = DateTime.now();

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DailyFeedbackModel? _feedbackForSelectedDate(DailyFeedbackProvider provider) {
    for (final f in provider.feedbacks) {
      if (f.classId != widget.classId || f.sectionId != widget.sectionId) continue;
      if (!f.recipientStudentIds.contains(widget.student.studentId)) continue;
      if (f.createdAt == null || f.createdAt!.isEmpty) continue;
      try {
        final d = DateTime.parse(f.createdAt!).toLocal();
        if (_isSameDay(d, _selectedDate)) return f;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Consumer<DailyFeedbackProvider>(
                      builder: (context, provider, _) {
                        final feedback = _feedbackForSelectedDate(provider);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDateChip(theme),
                              const SizedBox(height: 20),
                              if (feedback == null)
                                _buildNoFeedback(theme)
                              else
                                _buildFeedbackCard(context, theme, feedback),
                            ],
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
    final subtitle = [
      if (widget.student.className != null && widget.student.className!.isNotEmpty) widget.student.className,
      if (widget.student.sectionName != null && widget.student.sectionName!.isNotEmpty) widget.student.sectionName,
    ].join(' • ');
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
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(ThemeData theme) {
    final label = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoFeedback(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.feedback_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No feedback for this date',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the date above to choose another day',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditFeedback(BuildContext context, DailyFeedbackModel feedback) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DailyFeedbackFormScreen(
          feedbackId: feedback.id,
          existingFeedback: feedback,
        ),
      ),
    );
    if (result == true && mounted) {
      final staffId = context.read<AuthProvider>().currentUser?.uid;
      if (staffId != null) {
        context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback updated.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFeedbackCard(BuildContext context, ThemeData theme, DailyFeedbackModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: const SizedBox.shrink(),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openEditFeedback(context, model),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.edit_rounded, size: 20, color: AppColors.primaryBlue),
                  ),
                ),
              ),
            ],
          ),
          if (model.messageText != null && model.messageText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              model.messageText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (model.voiceUrl != null || model.attachments.isNotEmpty) const SizedBox(height: 12),
          ],
          if (model.voiceUrl != null && model.voiceUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VoicePlayerWidget(audioUrl: model.voiceUrl!),
            ),
          if (model.attachments.isNotEmpty) ...[
            if (model.voiceUrl != null && model.voiceUrl!.isNotEmpty) const SizedBox(height: 8),
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
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  const _LinkChip({required this.icon, required this.label, required this.url, required this.color});

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
