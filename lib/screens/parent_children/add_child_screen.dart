import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/domain/parent_link_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Form a guardian fills out to claim a child by one-time code.
///
/// The school admin issues a 6-character alphanumeric `mobile_app_code` on
/// the student's row; the parent types it in here. Outcomes:
///   • linked / already_linked → success snack + pop(true) (parent screen refreshes).
///   • unmatched / rejected    → inline error stays on the form.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final raw = auth.currentUser?.additionalData?['id'] ?? auth.currentUser?.id;
    final parentId =
        raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    if (parentId <= 0) {
      setState(() => _inlineError = 'Could not resolve guardian account.');
      return;
    }

    setState(() => _submitting = true);
    final result = await ParentLinkRepository.linkChildRequest(
      parentId: parentId,
      mobileAppCode: _codeCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result.outcome) {
      case LinkChildOutcome.linked:
        SiChrome.showMessage(
          context,
          result.child != null
              ? '${result.child!.fullName} linked successfully.'
              : 'Child linked successfully.',
        );
        Navigator.pop(context, true);
        break;
      case LinkChildOutcome.alreadyLinked:
        SiChrome.showMessage(
          context,
          result.child != null
              ? '${result.child!.fullName} is already linked to your account.'
              : 'This child is already linked to your account.',
        );
        Navigator.pop(context, true);
        break;
      case LinkChildOutcome.pendingApproval:
        // Not produced by the current server, but if a future flow brings it
        // back we still render a sensible message.
        await _showPendingDialog(result.message);
        if (!mounted) return;
        Navigator.pop(context, true);
        break;
      case LinkChildOutcome.unmatched:
      case LinkChildOutcome.rejected:
        setState(() {
          _inlineError = result.message ??
              'We could not link this child. Please double-check the code.';
        });
        break;
    }
  }

  Future<void> _showPendingDialog(String? serverMessage) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.hourglass_top_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Submitted for review'),
          ],
        ),
        content: Text(
          serverMessage ??
              'Your school admin will confirm this link soon. You will see '
              'your child here as soon as it is approved.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Add a child',
      subtitle: 'Enter the 6-character code from your school',
      child: Form(
        key: _formKey,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _IntroBlurb(),
            const SizedBox(height: 18),

            TextFormField(
              controller: _codeCtrl,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
                _UppercaseFormatter(),
              ],
              decoration: SiChrome.inputDecoration(
                context,
                labelText: 'Mobile app code',
                hintText: 'e.g. A1B2C3',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
              ),
              validator: (v) {
                final s = (v ?? '').trim().toUpperCase();
                if (s.isEmpty) {
                  return 'The code is required.';
                }
                if (s.length != 6) {
                  return 'The code must be exactly 6 characters.';
                }
                if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(s)) {
                  return 'Only letters and digits are allowed.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitting ? null : _submit(),
            ),

            if (_inlineError != null) ...[
              const SizedBox(height: 16),
              _InlineErrorBanner(message: _inlineError!),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_submitting ? 'Linking…' : 'Link child'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 18),
            const _HelpFooter(),
          ],
        ),
      ),
    );
  }
}

class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final up = newValue.text.toUpperCase();
    if (up == newValue.text) return newValue;
    return newValue.copyWith(
      text: up,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class _IntroBlurb extends StatelessWidget {
  const _IntroBlurb();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ask your school for the mobile app code printed on your '
              'child\'s profile. Each code can be used once — once you link a '
              'child here, the code is consumed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpFooter extends StatelessWidget {
  const _HelpFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.support_agent_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Don't have a code yet? Contact your school admin — they can "
              "generate or reset it for you.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
