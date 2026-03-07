import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/daily_feedback/daily_feedback_provider.dart';
import 'package:learining_portal/screens/feedback/voice_player_widget.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class DailyFeedbackFormScreen extends StatefulWidget {
  final int? feedbackId;
  final DailyFeedbackModel? existingFeedback;

  const DailyFeedbackFormScreen({
    super.key,
    this.feedbackId,
    this.existingFeedback,
  });

  @override
  State<DailyFeedbackFormScreen> createState() =>
      _DailyFeedbackFormScreenState();
}

class _DailyFeedbackFormScreenState extends State<DailyFeedbackFormScreen> {
  final TextEditingController _messageController = TextEditingController();

  int? _selectedClassId;
  int? _selectedSectionId;
  final Set<int> _selectedStudentIds = {};

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;
  String? _uploadedVoiceUrl;
  final List<MapEntry<String, String>> _pendingAttachments = [];
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DailyFeedbackProvider>();
      provider.loadClassesAndSections();
      if (widget.existingFeedback != null) {
        _prefillFrom(widget.existingFeedback!);
        if (_selectedClassId != null && _selectedSectionId != null) {
          provider.loadStudents(_selectedClassId!, _selectedSectionId!);
        }
      }
    });
  }

  void _prefillFrom(DailyFeedbackModel f) {
    _messageController.text = f.messageText ?? '';
    _uploadedVoiceUrl = f.voiceUrl;
    _recordedPath = null;
    _pendingAttachments.clear();
    for (final a in f.attachments) {
      _pendingAttachments.add(MapEntry(a.fileUrl, a.filename ?? 'Attachment'));
    }
    if (f.classId != null && f.classId! > 0) _selectedClassId = f.classId;
    if (f.sectionId != null && f.sectionId! > 0)
      _selectedSectionId = f.sectionId;
    _selectedStudentIds.addAll(f.recipientStudentIds);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record.'),
          ),
        );
      }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/feedback_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (mounted && path != null && path.isNotEmpty) {
        setState(() {
          _isRecording = false;
          _recordedPath = path;
          _uploadedVoiceUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
      }
    }
  }

  Future<String?> _uploadVoiceFile() async {
    if (_recordedPath == null) return null;
    final file = File(_recordedPath!);
    if (!await file.exists()) return null;
    final result = await context.read<DailyFeedbackProvider>().uploadFile(file);
    if (result['success'] == true && result['file_url'] != null) {
      return result['file_url'] as String;
    }
    return null;
  }

  Future<void> _pickAndUploadAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploadingAttachment = true);
    final provider = context.read<DailyFeedbackProvider>();
    for (final pf in result.files) {
      final path = pf.path;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final uploadResult = await provider.uploadFile(file);
      if (uploadResult['success'] == true && uploadResult['file_url'] != null) {
        if (mounted) {
          setState(() {
            _pendingAttachments.add(
              MapEntry(
                uploadResult['file_url'] as String,
                uploadResult['filename'] as String? ?? pf.name,
              ),
            );
          });
        }
      }
    }
    if (mounted) setState(() => _uploadingAttachment = false);
  }

  void _removePendingAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
  }

  Future<void> _submitFeedback() async {
    final staffId = context.read<AuthProvider>().currentUser?.uid;
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to submit feedback.'),
        ),
      );
      return;
    }

    final messageText = _messageController.text.trim();
    final hasVoice = _uploadedVoiceUrl != null || _recordedPath != null;
    final hasAttachments = _pendingAttachments.isNotEmpty;

    if (messageText.isEmpty && !hasVoice && !hasAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a message, voice recording, or attachment.'),
        ),
      );
      return;
    }

    String? voiceUrl = _uploadedVoiceUrl;
    if (_recordedPath != null && voiceUrl == null) {
      voiceUrl = await _uploadVoiceFile();
      if (mounted) setState(() => _uploadedVoiceUrl = voiceUrl);
      if (voiceUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice upload failed. Try again or submit without voice.',
            ),
          ),
        );
        return;
      }
    }

    final attachmentUrls = _pendingAttachments.map((e) => e.key).toList();
    final provider = context.read<DailyFeedbackProvider>();
    final success = await provider.saveFeedback(
      staffId: staffId,
      feedbackId: widget.feedbackId,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      recipientStudentIds: _selectedStudentIds.isEmpty
          ? null
          : _selectedStudentIds.toList(),
      messageText: messageText.isEmpty ? null : messageText,
      voiceUrl: voiceUrl,
      attachmentUrls: attachmentUrls.isEmpty ? null : attachmentUrls,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.feedbackId != null ? 'Feedback updated.' : 'Feedback saved.',
          ),
          backgroundColor: AppColors.accentTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.saveError ?? 'Failed to save feedback'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                    ],
                  ),
                  child: Consumer<DailyFeedbackProvider>(
                    builder: (context, provider, _) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTargetingSection(theme, provider),
                            const SizedBox(height: 20),
                            _buildMessageAndMediaSection(
                              context,
                              theme,
                              provider,
                            ),
                            const SizedBox(height: 20),
                            _buildSaveButton(theme, provider),
                          ],
                        ),
                      );
                    },
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
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.feedbackId != null ? "Edit feedback" : 'New feedback',
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

  Widget _buildTargetingSection(
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    final classes = provider.classes;
    final sections = provider.sections;
    final students = provider.students;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Target class & students',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _selectedClassId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— Select —'),
                    ),
                    ...classes.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.className, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: provider.loadingClasses
                      ? null
                      : (v) {
                          setState(() {
                            _selectedClassId = v;
                            _selectedSectionId = null;
                            _selectedStudentIds.clear();
                          });
                          provider.clearStudents();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _selectedSectionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Section',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— Select —'),
                    ),
                    ...sections.map(
                      (s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.sectionName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: provider.loadingSections
                      ? null
                      : (v) {
                          setState(() {
                            _selectedSectionId = v;
                            _selectedStudentIds.clear();
                          });
                          if (_selectedClassId != null && v != null) {
                            provider.loadStudents(_selectedClassId!, v);
                          } else {
                            provider.clearStudents();
                          }
                        },
                ),
              ),
            ],
          ),
          if (_selectedClassId != null && _selectedSectionId != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Students',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (students.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedStudentIds.length == students.length) {
                          _selectedStudentIds.clear();
                        } else {
                          _selectedStudentIds.addAll(
                            students.map((s) => s.studentId),
                          );
                        }
                      });
                    },
                    child: Text(
                      _selectedStudentIds.length == students.length
                          ? 'Deselect all'
                          : 'Select all',
                      style: TextStyle(
                        color: AppColors.accentTeal,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            if (provider.loadingStudents)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (students.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No students in this class/section.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    final selected = _selectedStudentIds.contains(s.studentId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedStudentIds.add(s.studentId);
                          } else {
                            _selectedStudentIds.remove(s.studentId);
                          }
                        });
                      },
                      title: Text(
                        'Student ${s.studentId}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageAndMediaSection(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.backgroundLight.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.secondaryPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Message, voice & attachments',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Written feedback',
              hintText: 'Type your message here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: provider.saving || _uploadingAttachment
                      ? null
                      : (_isRecording ? _stopRecording : _startRecording),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (_isRecording ? Colors.red : AppColors.accentTeal)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            (_isRecording ? Colors.red : AppColors.accentTeal)
                                .withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 22,
                          color: _isRecording
                              ? Colors.red
                              : AppColors.accentTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording ? 'Stop' : 'Record voice',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isRecording
                                ? Colors.red
                                : AppColors.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_recordedPath != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accentTeal.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _uploadedVoiceUrl != null
                        ? 'Voice ready'
                        : 'Voice recorded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accentTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_recordedPath != null) ...[
            const SizedBox(height: 12),
            VoicePlayerWidget(localPath: _recordedPath),
          ],
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: provider.saving || _uploadingAttachment
                  ? null
                  : _pickAndUploadAttachments,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.secondaryPurple.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _uploadingAttachment
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.secondaryPurple,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.attach_file_rounded,
                            size: 22,
                            color: AppColors.secondaryPurple,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      _uploadingAttachment ? 'Uploading...' : 'Add attachments',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_pendingAttachments.isNotEmpty)
            ...List.generate(_pendingAttachments.length, (i) {
              final e = _pendingAttachments[i];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(e.value, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _removePendingAttachment(i),
                  ),
                ),
              );
            }),
          if (provider.saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                provider.saveError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme, DailyFeedbackProvider provider) {
    final saving = provider.saving;
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saving ? null : _submitFeedback,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              gradient: saving
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.secondaryPurple,
                      ],
                    ),
              color: saving ? AppColors.textSecondary.withOpacity(0.3) : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: saving
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.feedbackId != null
                          ? 'Update feedback'
                          : 'Save feedback',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
