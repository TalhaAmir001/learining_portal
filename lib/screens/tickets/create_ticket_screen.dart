import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/support_ticket/support_ticket_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/support_tickets_provider.dart';
import 'package:learining_portal/screens/tickets/ticket_detail_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategorySlug;
  String? _selectedPriority;
  String? _attachmentUrl;
  String? _attachmentFileName;
  String? _attachmentLocalPath; // for image preview before upload
  bool _isSubmitting = false;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportTicketsProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  Future<void> _pickAndUploadAttachment() async {
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
    final provider = context.read<SupportTicketsProvider>();
    final uploadResult = await provider.uploadAttachment(File(path));
    setState(() {
      _uploadingAttachment = false;
      if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
        _attachmentUrl = uploadResult['file_url'] as String;
        _attachmentFileName = uploadResult['filename'] as String? ?? name;
        _attachmentLocalPath = isImage ? path : null;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final provider = context.read<SupportTicketsProvider>();

    final result = await provider.createTicket(
      auth: auth,
      subject: _subjectController.text.trim(),
      category: _selectedCategorySlug,
      priority: _selectedPriority,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      attachment: _attachmentUrl,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ticket submitted successfully'),
          backgroundColor: AppColors.accentTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final ticketId = result['id'] as int?;
      if (ticketId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(
              ticketId: ticketId,
              ticketSubject: _subjectController.text.trim(),
            ),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to create ticket'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _subjectController,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Subject',
                                hintText: 'Brief summary of your issue',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                                prefixIcon: const Icon(
                                  Icons.subject_rounded,
                                  color: AppColors.accentTeal,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceWhite,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter a subject';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildCategoryDropdown(context),
                            const SizedBox(height: 16),
                            _buildPriorityDropdown(context),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Description (optional)',
                                hintText: 'Describe your issue in detail',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 60),
                                  child: Icon(
                                    Icons.description_rounded,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceWhite,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAttachmentSection(context),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentTeal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text('Submit Ticket'),
                              ),
                            ),
                          ],
                        ),
                      ),
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
          Text(
            'New Ticket',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return Consumer<SupportTicketsProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories
            .where((c) => c.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (categories.isEmpty && !provider.isLoadingCategories) {
          return const SizedBox.shrink();
        }
        if (categories.isEmpty) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return DropdownButtonFormField<String>(
          value: _selectedCategorySlug,
          decoration: InputDecoration(
            labelText: 'Category (optional)',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(
              Icons.category_rounded,
              color: AppColors.accentTeal,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
            ),
            filled: true,
            fillColor: AppColors.surfaceWhite,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('None'),
            ),
            ...categories.map(
              (c) => DropdownMenuItem<String>(
                value: c.slug,
                child: Text(c.name),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedCategorySlug = v),
        );
      },
    );
  }

  Widget _buildPriorityDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedPriority,
      decoration: InputDecoration(
        labelText: 'Priority (optional)',
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(
          Icons.flag_rounded,
          color: AppColors.accentTeal,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
        ),
        filled: true,
        fillColor: AppColors.surfaceWhite,
      ),
      items: const [
        DropdownMenuItem<String>(value: null, child: Text('None')),
        DropdownMenuItem<String>(value: 'low', child: Text('Low')),
        DropdownMenuItem<String>(value: 'medium', child: Text('Medium')),
        DropdownMenuItem<String>(value: 'high', child: Text('High')),
      ],
      onChanged: (v) => setState(() => _selectedPriority = v),
    );
  }

  Widget _buildAttachmentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachment (optional)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        if (_uploadingAttachment)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          )
        else if (_attachmentUrl != null) ...[
          _buildAttachmentPreviewCard(context),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickAndUploadAttachment,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Change file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              side: const BorderSide(color: AppColors.accentTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: _pickAndUploadAttachment,
            icon: const Icon(Icons.attach_file_rounded),
            label: const Text('Attach file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              side: const BorderSide(color: AppColors.accentTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentPreviewCard(BuildContext context) {
    final isImage = _attachmentLocalPath != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentTeal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (isImage && _attachmentLocalPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_attachmentLocalPath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: AppColors.accentTeal,
                size: 28,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _attachmentFileName ?? 'Attachment',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to send',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentTeal,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _attachmentUrl = null;
              _attachmentFileName = null;
              _attachmentLocalPath = null;
            }),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceWhite,
            ),
          ),
        ],
      ),
    );
  }
}
