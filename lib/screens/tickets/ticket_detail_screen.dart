import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:learining_portal/network/data_models/support_ticket/support_ticket_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/support_tickets_provider.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final String ticketSubject;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.ticketSubject,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  SupportTicketModel? _ticket;
  bool _loading = true;
  final _replyController = TextEditingController();
  String? _replyAttachmentUrl;
  String? _replyAttachmentFileName;
  String? _replyAttachmentLocalPath;
  bool _sendingReply = false;
  bool _uploadingAttachment = false;

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ticket = await context.read<SupportTicketsProvider>().getTicketDetail(
      auth: auth,
      ticketId: widget.ticketId,
    );
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadReplyAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    final name = file.name;
    final ext = name.split('.').last.toLowerCase();
    final isImage = _imageExtensions.contains(ext);

    setState(() => _uploadingAttachment = true);
    final uploadResult = await context
        .read<SupportTicketsProvider>()
        .uploadAttachment(File(path));
    setState(() {
      _uploadingAttachment = false;
      if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
        _replyAttachmentUrl = uploadResult['file_url'] as String;
        _replyAttachmentFileName = uploadResult['filename'] as String? ?? name;
        _replyAttachmentLocalPath = isImage ? path : null;
      }
    });
    if (mounted && uploadResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['error']?.toString() ?? 'Upload failed'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty && _replyAttachmentUrl == null) return;
    if (_sendingReply) return;

    setState(() => _sendingReply = true);

    final auth = context.read<AuthProvider>();
    final result = await context.read<SupportTicketsProvider>().addReply(
      auth: auth,
      supportTicketId: widget.ticketId,
      message: message.isEmpty ? '(attachment)' : message,
      attachment: _replyAttachmentUrl,
    );

    if (!mounted) return;
    setState(() => _sendingReply = false);

    if (result['success'] == true) {
      _replyController.clear();
      setState(() {
        _replyAttachmentUrl = null;
        _replyAttachmentFileName = null;
        _replyAttachmentLocalPath = null;
      });
      await _loadTicket();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reply sent'),
          backgroundColor: AppColors.accentTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to send reply'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Students, parents, teachers and admins can all reply (when ticket is open/in progress/pending).
  bool _canReply(BuildContext context) {
    return true;
  }

  String _fullAttachmentUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
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
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentTeal,
                              ),
                            ),
                          )
                        : _ticket == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 56,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ticket not found',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('Back'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTicketHeader(context, _ticket!),
                                      if (_ticket!.description != null &&
                                          _ticket!.description!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildDescription(context),
                                      ],
                                      if (_ticket!.attachment != null &&
                                          _ticket!.attachment!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildTicketAttachment(context),
                                      ],
                                      const SizedBox(height: 24),
                                      Text(
                                        'Conversation',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      ..._ticket!.replies.map(
                                        (r) => _buildReply(context, r),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!_ticket!.isClosed &&
                                  !_ticket!.isResolved &&
                                  _canReply(context))
                                _buildReplyBar(context),
                            ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ticketSubject,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_ticket != null)
                  Text(
                    _ticket!.ticketId,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketHeader(BuildContext context, SupportTicketModel ticket) {
    final statusColor = _statusColor(ticket.status);
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(ticket.status),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (ticket.priority != null && ticket.priority!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Priority: ${ticket.priority}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (ticket.category != null && ticket.category!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Category: ${ticket.category}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (ticket.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Created ${_formatDate(ticket.createdAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachmentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTicketAttachment(BuildContext context) {
    final url = _fullAttachmentUrl(_ticket!.attachment);
    if (url.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _openAttachmentUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentTeal.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.accentTeal, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'View attachment',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.accentTeal,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.accentTeal),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ticket!.description!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildReply(BuildContext context, SupportTicketReplyModel reply) {
    final isStaff = reply.isFromStaff;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isStaff
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isStaff) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accentTeal.withOpacity(0.2),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.accentTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStaff
                    ? AppColors.accentTeal.withOpacity(0.12)
                    : AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isStaff ? 4 : 16),
                  bottomRight: Radius.circular(isStaff ? 16 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStaff ? 'Support' : 'You',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isStaff
                          ? AppColors.accentTeal
                          : AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (reply.attachment != null &&
                      reply.attachment!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        final url = _fullAttachmentUrl(reply.attachment);
                        if (url.isNotEmpty) _openAttachmentUrl(url);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 16,
                            color: AppColors.accentTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Attachment',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.accentTeal,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (reply.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(reply.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isStaff) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyAttachmentUrl != null) ...[
            _buildReplyAttachmentPreview(context),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _uploadingAttachment
                    ? null
                    : _pickAndUploadReplyAttachment,
                icon: _uploadingAttachment
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentTeal,
                          ),
                        ),
                      )
                    : const Icon(Icons.attach_file_rounded),
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type a reply...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppColors.textSecondary.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppColors.textSecondary.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.accentTeal,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendingReply ? null : _sendReply,
                icon: _sendingReply
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyAttachmentPreview(BuildContext context) {
    final isImage = _replyAttachmentLocalPath != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentTeal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (isImage && _replyAttachmentLocalPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_replyAttachmentLocalPath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: AppColors.accentTeal,
                size: 22,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _replyAttachmentFileName ?? 'Attachment',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _replyAttachmentUrl = null;
              _replyAttachmentFileName = null;
              _replyAttachmentLocalPath = null;
            }),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.backgroundLight,
              padding: const EdgeInsets.all(4),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.primaryBlue;
      case 'in_progress':
        return AppColors.accentTeal;
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In progress';
      case 'pending':
        return 'Pending';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
