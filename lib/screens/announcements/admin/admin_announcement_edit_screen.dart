import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/data_models/announcement/announcement_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/network/domain/announcement_feed_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class AdminAnnouncementEditScreen extends StatefulWidget {
  const AdminAnnouncementEditScreen({super.key, this.existing});

  final AnnouncementPost? existing;

  @override
  State<AdminAnnouncementEditScreen> createState() =>
      _AdminAnnouncementEditScreenState();
}

class _AdminAnnouncementEditScreenState extends State<AdminAnnouncementEditScreen> {
  bool _loading = true;
  String? _error;
  AdminAcMetaPayload? _meta;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  int? _classId;
  int? _sectionId;
  bool _isPublished = true;

  String _mediaChoice = 'none'; // none|image|video_upload|video_embed
  String _embedProvider = 'youtube';
  final TextEditingController _embedUrlCtrl = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;

  bool _saving = false;

  bool get _isEdit => (widget.existing?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _bodyCtrl = TextEditingController(text: existing?.body ?? '');
    _isPublished = existing?.isPublished ?? true;

    final mt = existing?.mediaType ?? 'none';
    if (mt == 'image') _mediaChoice = 'image';
    if (mt == 'video_upload') _mediaChoice = 'video_upload';
    if (mt == 'video_embed') _mediaChoice = 'video_embed';
    _embedProvider = (existing?.embedProvider.isNotEmpty ?? false)
        ? existing!.embedProvider
        : 'youtube';
    _embedUrlCtrl.text = existing?.embedUrl ?? '';

    _classId = existing?.classId;
    _sectionId = existing?.sectionId;

    _loadMeta();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _embedUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await AcademicsRepository.getAdminAcademicsMeta();
      _meta = meta;
      if (!meta.success) {
        _error = meta.error ?? 'Failed to load classes/sections.';
      } else {
        _classId ??= meta.classes.isNotEmpty ? meta.classes.first.id : null;
        _sectionId ??= meta.sections.isNotEmpty ? meta.sections.first.id : null;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickFile({required bool isVideo}) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isVideo
          ? const ['mp4', 'webm', 'ogg']
          : const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: false,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.path == null) return;
    setState(() {
      _pickedFilePath = f.path;
      _pickedFileName = f.name;
    });
  }

  Future<void> _save() async {
    final meta = _meta;
    final classId = _classId;
    final sectionId = _sectionId;
    if (meta == null || !meta.success) {
      SiChrome.showMessage(context, meta?.error ?? 'Meta not available');
      return;
    }
    if (classId == null || sectionId == null) {
      SiChrome.showMessage(context, 'Select class and section');
      return;
    }

    if (_mediaChoice == 'video_embed') {
      final url = _embedUrlCtrl.text.trim();
      if (url.isEmpty) {
        SiChrome.showMessage(context, 'Enter a video URL');
        return;
      }
    }
    if (_mediaChoice == 'image' || _mediaChoice == 'video_upload') {
      // allow keeping existing media on edit; for new post require a file
      if (!_isEdit && (_pickedFilePath == null || _pickedFilePath!.isEmpty)) {
        SiChrome.showMessage(context, 'Pick a file');
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    final createdByStaffId = auth.currentUser?.portalStaffId;

    setState(() => _saving = true);
    try {
      final r = await AnnouncementFeedRepository.upsertAdmin(
        id: widget.existing?.id,
        classId: classId,
        sectionId: sectionId,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        isPublished: _isPublished,
        mediaChoice: _mediaChoice,
        embedProvider: _embedProvider,
        embedUrl: _embedUrlCtrl.text.trim(),
        mediaFilePath: _pickedFilePath,
        createdByStaffId: createdByStaffId,
      );
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.pop<bool>(context, true);
      } else {
        SiChrome.showMessage(context, (r['error'] ?? 'Save failed').toString());
      }
    } catch (e) {
      if (!mounted) return;
      SiChrome.showMessage(context, e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return SiThemedPageScaffold(
      title: _isEdit ? 'Edit Announcement' : 'New Announcement',
      subtitle: 'Admin',
      actions: [
        IconButton(
          icon: const Icon(Icons.save_rounded),
          color: Colors.white,
          onPressed: _loading || _saving ? null : _save,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : (meta == null || !meta.success)
              ? SiEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load',
                  message: _error ?? meta?.error,
                )
              : Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        Card(
                          elevation: 0,
                          color: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                InputDecorator(
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Class',
                                    prefixIcon: const Icon(Icons.class_rounded),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _classId,
                                      isExpanded: true,
                                      items: meta.classes
                                          .map((c) => DropdownMenuItem(
                                                value: c.id,
                                                child: Text(c.name),
                                              ))
                                          .toList(),
                                      onChanged: (v) => setState(() => _classId = v),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InputDecorator(
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Section',
                                    prefixIcon: const Icon(Icons.view_list_rounded),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _sectionId,
                                      isExpanded: true,
                                      items: meta.sections
                                          .map((s) => DropdownMenuItem(
                                                value: s.id,
                                                child: Text(s.name),
                                              ))
                                          .toList(),
                                      onChanged: (v) => setState(() => _sectionId = v),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _titleCtrl,
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Title (optional)',
                                    prefixIcon: const Icon(Icons.title_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _bodyCtrl,
                                  maxLines: 6,
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Body (optional)',
                                    prefixIcon: const Icon(Icons.notes_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  value: _isPublished,
                                  onChanged: (v) => setState(() => _isPublished = v),
                                  title: const Text('Published'),
                                  subtitle: const Text('Visible to students'),
                                  activeColor: AppColors.accentTeal,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Media',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                InputDecorator(
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Media type',
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _mediaChoice,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'none',
                                          child: Text('None'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'image',
                                          child: Text('Image upload'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'video_upload',
                                          child: Text('Video upload'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'video_embed',
                                          child: Text('Video embed (YouTube/Loom)'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _mediaChoice = v;
                                          _pickedFilePath = null;
                                          _pickedFileName = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                if (_mediaChoice == 'image') ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : () => _pickFile(isVideo: false),
                                    icon: const Icon(Icons.image_rounded),
                                    label: Text(_pickedFileName ?? 'Pick image'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      side: BorderSide(
                                        color: AppColors.primaryBlue.withOpacity(0.35),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_mediaChoice == 'video_upload') ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : () => _pickFile(isVideo: true),
                                    icon: const Icon(Icons.ondemand_video_rounded),
                                    label: Text(_pickedFileName ?? 'Pick video'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      side: BorderSide(
                                        color: AppColors.primaryBlue.withOpacity(0.35),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_mediaChoice == 'video_embed') ...[
                                  const SizedBox(height: 12),
                                  InputDecorator(
                                    decoration: SiChrome.inputDecoration(
                                      context,
                                      labelText: 'Provider',
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _embedProvider,
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'youtube',
                                            child: Text('YouTube'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'loom',
                                            child: Text('Loom'),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() => _embedProvider = v);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _embedUrlCtrl,
                                    decoration: SiChrome.inputDecoration(
                                      context,
                                      labelText: 'Video URL',
                                      hintText: 'Paste YouTube or Loom link',
                                      prefixIcon: const Icon(Icons.link_rounded),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    if (_saving)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.35),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
    );
  }
}

