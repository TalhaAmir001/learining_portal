// lib/utils/widgets/messages/ticket_floating_bar.dart
import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:learining_portal/providers/messages/chat_provider.dart';
import 'package:learining_portal/screens/tickets/tickets_list_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// A floating bar above the chat input. Shows "Is the issue resolved?" with Yes (tick) and No (cross).
/// Yes: opens a dialog to rate experience with 5 stars, then saves support feedback.
/// No: shows a dialog asking "Issue not solved, would you like to generate a ticket?"; on OK, opens the Tickets screen.
class TicketFloatingBar extends StatefulWidget {
  /// Optional custom callback when the user taps the ticket action (Yes path).
  /// If null, the default behavior shows the rating dialog and saves support feedback via API.
  final VoidCallback? onGenerateTicket;

  const TicketFloatingBar({super.key, this.onGenerateTicket});

  @override
  State<TicketFloatingBar> createState() => _TicketFloatingBarState();
}

class _TicketFloatingBarState extends State<TicketFloatingBar> {
  bool _isOpen = true;

  void _onYesPressed(BuildContext context) {
    if (widget.onGenerateTicket != null) {
      widget.onGenerateTicket!();
      return;
    }
    _showRatingDialog(context);
  }

  Future<void> _onNoPressed(BuildContext context) async {
    final openTickets = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.accentTeal, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Generate ticket?')),
          ],
        ),
        content: const Text(
          'Issue not solved, would you like to generate a ticket?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentTeal),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (openTickets == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TicketsListScreen(),
        ),
      );
    }
  }

  static const int _maxStars = 5;

  Future<void> _showRatingDialog(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();
    final connectionId = chatProvider.chatId;
    if (connectionId == null || connectionId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No chat connection. Please wait or reopen the chat.'),
          ),
        );
      }
      return;
    }

    int? selectedRating;

    if (!context.mounted) return;
    final submittedRating = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.star_rounded, color: AppColors.accentTeal, size: 28),
                  const SizedBox(width: 10),
                  const Text('Rate your experience'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was your support experience?',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_maxStars, (index) {
                      final starRating = index + 1;
                      final isSelected = selectedRating != null && selectedRating! >= starRating;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedRating = starRating),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: isSelected
                                ? AppColors.accentTeal
                                : Colors.grey.shade400,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (selectedRating != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${selectedRating!} / 5',
                        style: TextStyle(
                          color: AppColors.accentTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                FilledButton(
                  onPressed: selectedRating == null
                      ? null
                      : () {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(selectedRating);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submittedRating == null) return;

    final feedbackText = 'Experience rating: $submittedRating/5';
    final result = await MessagesChatRepository.saveSupportFeedback(
      connectionId: connectionId,
      feedbackText: feedbackText,
    );

    if (!context.mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Thank you for your feedback!'),
          backgroundColor: AppColors.accentTeal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to save feedback'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildArrowTab() {
    return Material(
      color: AppColors.backgroundLight,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: InkWell(
        onTap: () => setState(() => _isOpen = !_isOpen),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        child: Container(
          width: 28,
          height: 44,
          alignment: Alignment.center,
          child: AnimatedRotation(
            turns: _isOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.chevron_right,
              color: AppColors.primaryBlue,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _buildArrowTab(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildArrowTab(),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.accentTeal,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Is the issue resolved?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onYesPressed(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onNoPressed(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.cancel_outlined,
                            color: Colors.red.shade700,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
