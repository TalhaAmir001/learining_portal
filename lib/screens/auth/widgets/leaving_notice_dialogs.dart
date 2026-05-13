import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/domain/parent_leaving_repository.dart';

/// Two-step "End Subscription" flow rendered as dialogs:
///   1. [_LeavingPolicyDialog]   — read-only policy + confirmation checkbox.
///   2. [_LeavingFormDialog]     — reason text + leaving date picker.
///
/// The public entrypoint is [showEndSubscriptionFlow]. The caller passes the
/// authenticated `app_parents.id` (and optionally the currently-active child)
/// — the backend uses both to record the notice, so the parent doesn't have
/// to re-enter credentials and the saved row carries an audit snapshot of
/// which child was active at submission time.
const int kLeavingNoticeMinDays = 28;
const String _kCheckboxText =
    'I understand that GCSEwithRosi requires 4 weeks\u2019 notice and that any '
    'payments made during the notice period are non-refundable.';
const String _kRecommendedNote =
    'We recommend submitting your notice before your next billing date if you '
    'wish to avoid additional charges during the notice period.';

/// Drives the full flow. Returns `true` if the parent submitted a notice that
/// the server accepted, `false` if they cancelled at any step or submission
/// failed (errors are surfaced inline to the parent before this resolves).
///
/// [activeChild] is shown in the form dialog and submitted to the backend
/// for the audit trail. May be `null` if the parent hasn't linked / picked
/// a child yet, in which case the child snapshot section is omitted.
Future<bool> showEndSubscriptionFlow({
  required BuildContext context,
  required int appParentId,
  ParentChild? activeChild,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LeavingPolicyDialog(),
  );
  if (agreed != true) return false;

  if (!context.mounted) return false;

  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LeavingFormDialog(
      appParentId: appParentId,
      activeChild: activeChild,
    ),
  );
  return submitted == true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Policy notice
// ─────────────────────────────────────────────────────────────────────────────

class _LeavingPolicyDialog extends StatefulWidget {
  const _LeavingPolicyDialog();

  @override
  State<_LeavingPolicyDialog> createState() => _LeavingPolicyDialogState();
}

class _LeavingPolicyDialogState extends State<_LeavingPolicyDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LeavingPolicyHeader(colorScheme: colorScheme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: _LeavingPolicyBody(),
              ),
            ),
            _LeavingPolicyFooter(
              accepted: _accepted,
              onAcceptedChanged: (v) => setState(() => _accepted = v),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeavingPolicyHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  const _LeavingPolicyHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GCSEwithRosi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Leaving Notice Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeavingPolicyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: Colors.grey[850],
    );
    final headingStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Colors.grey[900],
      height: 1.4,
    );
    final bulletStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: Colors.grey[850],
    );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  height: 5,
                  width: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: bulletStyle),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GCSEwithRosi requires a minimum of 4 weeks\u2019 notice before '
          'lessons can be stopped.',
          style: bodyStyle,
        ),
        const SizedBox(height: 14),
        Text(
          'When a parent submits the Leaving Notice Form:',
          style: headingStyle,
        ),
        const SizedBox(height: 8),
        bullet('The system should automatically set the leaving date to '
            '4 weeks from the submission date.'),
        bullet('Lessons and portal access will continue during this 4-week '
            'notice period.'),
        bullet('Payments already scheduled within this 4-week period will '
            'still be taken and are non-refundable.'),
        bullet('No further payments should be taken after the 4-week notice '
            'period ends.'),
        const SizedBox(height: 12),
        Text('Portal & Learning Access:', style: headingStyle),
        const SizedBox(height: 6),
        Text(
          'Your child will continue to have full access to their classes, '
          'recordings, homework, assessments, and portal during the 4-week '
          'notice period.',
          style: bodyStyle,
        ),
        const SizedBox(height: 10),
        Text(
          'If a payment has already been made covering dates beyond the '
          '4-week notice period, the student should continue to have access '
          'to the portal and learning materials until the end of the fully '
          'paid period.',
          style: bodyStyle,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: Colors.amber[800],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _kRecommendedNote,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeavingPolicyFooter extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onAcceptedChanged;
  final ColorScheme colorScheme;

  const _LeavingPolicyFooter({
    required this.accepted,
    required this.onAcceptedChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onAcceptedChanged(!accepted),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: accepted,
                    onChanged: (v) => onAcceptedChanged(v ?? false),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _kCheckboxText,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.grey[850],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: accepted
                    ? () => Navigator.of(context).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Agree',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Reason + leaving date form
// ─────────────────────────────────────────────────────────────────────────────

class _LeavingFormDialog extends StatefulWidget {
  final int appParentId;
  final ParentChild? activeChild;
  const _LeavingFormDialog({
    required this.appParentId,
    this.activeChild,
  });

  @override
  State<_LeavingFormDialog> createState() => _LeavingFormDialogState();
}

class _LeavingFormDialogState extends State<_LeavingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  DateTime? _leavingDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  late final DateTime _earliest;
  late final DateTime _latest;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _earliest = today.add(const Duration(days: kLeavingNoticeMinDays));
    _latest = today.add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final colorScheme = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _leavingDate ?? _earliest,
      firstDate: _earliest,
      lastDate: _latest,
      helpText: 'Select your leaving date',
      cancelText: 'Cancel',
      confirmText: 'Select',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: colorScheme.primary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _leavingDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (_leavingDate == null) {
      setState(() => _errorMessage = 'Please pick a leaving date.');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ParentLeavingRepository.submit(
      appParentId: widget.appParentId,
      reason: _reasonCtrl.text,
      leavingDate: _leavingDate!,
      activeStudentId: widget.activeChild?.studentId,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      _showSuccessSnackBar();
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = result.error ?? 'Something went wrong. Please try again.';
    });
  }

  void _showSuccessSnackBar() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'We will further notify you with details in future.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LeavingFormHeader(colorScheme: colorScheme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active-child snapshot. Shown only when the parent
                      // has actually picked one — keeps the dialog clean
                      // for parents who haven't linked any kids yet.
                      if (widget.activeChild != null) ...[
                        _SectionLabel(
                          icon: Icons.person_outline_rounded,
                          label: 'Active child',
                        ),
                        const SizedBox(height: 8),
                        _ActiveChildCard(
                          child: widget.activeChild!,
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(height: 18),
                      ],
                      _SectionLabel(
                        icon: Icons.edit_note_rounded,
                        label: 'Reason for leaving',
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 5,
                        minLines: 3,
                        maxLength: 4000,
                        enabled: !_isSubmitting,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Let us know why you\u2019re leaving\u2026',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.6,
                            ),
                          ),
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a reason.';
                          }
                          if (v.trim().length < 4) {
                            return 'Please add a little more detail.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(
                        icon: Icons.calendar_today_rounded,
                        label: 'Leaving date',
                      ),
                      const SizedBox(height: 8),
                      _DateField(
                        date: _leavingDate,
                        enabled: !_isSubmitting,
                        onTap: _pickDate,
                        colorScheme: colorScheme,
                        earliest: _earliest,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Earliest available: ${_formatDate(_earliest)} '
                          '(per the 4-week notice policy).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            _LeavingFormFooter(
              isSubmitting: _isSubmitting,
              onCancel: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              onSubmit: _isSubmitting ? null : _submit,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeavingFormHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  const _LeavingFormHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'End Subscription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Submit your leaving notice',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeavingFormFooter extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final ColorScheme colorScheme;
  const _LeavingFormFooter({
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Notice',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Read-only card that surfaces "this is the child whose subscription you
/// are about to end" on the form dialog. The same name/admission combo is
/// also persisted server-side so admins see the snapshot when reviewing
/// the notice in the back office.
class _ActiveChildCard extends StatelessWidget {
  final ParentChild child;
  final ColorScheme colorScheme;
  const _ActiveChildCard({
    required this.child,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFrom(child);
    final classLabel = child.classLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.06),
            colorScheme.secondary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child.fullName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (child.admissionNo.isNotEmpty)
                      _PillChip(
                        icon: Icons.badge_outlined,
                        text: child.admissionNo,
                        color: colorScheme.primary,
                      ),
                    if (classLabel.isNotEmpty)
                      _PillChip(
                        icon: Icons.class_outlined,
                        text: classLabel,
                        color: colorScheme.secondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initialsFrom(ParentChild c) {
    String firstChar(String s) => s.trim().isEmpty
        ? ''
        : s.trim().substring(0, 1).toUpperCase();
    final a = firstChar(c.firstname);
    final b = firstChar(c.lastname);
    final combined = '$a$b';
    if (combined.isNotEmpty) return combined;
    if (c.firstname.isNotEmpty) return firstChar(c.firstname);
    return '#';
  }
}

/// Small label-style chip used by [_ActiveChildCard]. Self-contained so the
/// chip stays consistent across both displayed pieces of meta (admission +
/// class) without each having to repeat the styling.
class _PillChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _PillChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final DateTime earliest;
  const _DateField({
    required this.date,
    required this.enabled,
    required this.onTap,
    required this.colorScheme,
    required this.earliest,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = date != null;
    final label = hasValue
        ? _formatDate(date!)
        : 'Tap to choose a date';

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue
                ? colorScheme.primary.withOpacity(0.55)
                : Colors.grey[300]!,
            width: hasValue ? 1.6 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              size: 20,
              color: hasValue ? colorScheme.primary : Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      hasValue ? FontWeight.w600 : FontWeight.w500,
                  color: hasValue ? Colors.grey[900] : Colors.grey[600],
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = d.day.toString().padLeft(2, '0');
  final month = months[d.month - 1];
  return '$day $month ${d.year}';
}
