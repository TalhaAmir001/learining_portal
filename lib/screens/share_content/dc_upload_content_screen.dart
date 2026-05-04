import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Pick a file and upload it into the portal download center (`upload_contents`).
class DcUploadContentScreen extends StatefulWidget {
  const DcUploadContentScreen({super.key});

  @override
  State<DcUploadContentScreen> createState() => _DcUploadContentScreenState();
}

class _DcUploadContentScreenState extends State<DcUploadContentScreen> {
  bool _loadingTypes = true;
  List<DcContentTypeModel> _types = [];
  int? _contentTypeId;
  PlatformFile? _picked;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _loadingTypes = true);
    final list = await ShareContentRepository.getContentTypes();
    if (!mounted) return;
    setState(() {
      _types = list;
      _loadingTypes = false;
      if (_contentTypeId == null && list.isNotEmpty) {
        _contentTypeId = list.first.id;
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: false,
      withData: kIsWeb,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    setState(() => _picked = result.files.single);
  }

  Future<void> _upload() async {
    final picked = _picked;
    final typeId = _contentTypeId;
    if (picked == null || typeId == null) {
      SiChrome.showMessage(context, 'Choose a content type and a file.');
      return;
    }
    final name = picked.name;
    if (name.isEmpty) {
      SiChrome.showMessage(context, 'Invalid file name.');
      return;
    }

    final uploadBy = context.read<AuthProvider>().portalStaffId ?? 0;

    setState(() => _uploading = true);
    final Map<String, dynamic> result;
    if (picked.path != null && picked.path!.isNotEmpty) {
      result = await ShareContentRepository.uploadDcContent(
        contentTypeId: typeId,
        uploadBy: uploadBy,
        filename: name,
        filePath: picked.path,
      );
    } else if (picked.bytes != null) {
      result = await ShareContentRepository.uploadDcContent(
        contentTypeId: typeId,
        uploadBy: uploadBy,
        filename: name,
        fileBytes: picked.bytes!.toList(),
      );
    } else {
      result = {'success': false, 'error': 'Could not read file data. Try again.'};
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (result['success'] == true) {
      SiChrome.showMessage(
        context,
        result['message']?.toString() ?? 'Upload complete.',
      );
      setState(() => _picked = null);
    } else {
      final full = result['error']?.toString() ?? 'Upload failed.';
      debugPrint('upload_dc error:\n$full');
      debugPrint('upload_dc raw: $result');
      if (!context.mounted) return;
      _showUploadErrorDialog(context, full);
    }
  }

  void _showUploadErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload failed'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (ctx.mounted) Navigator.pop(ctx);
              if (!context.mounted) return;
              SiChrome.showMessage(context, 'Error details copied to clipboard');
            },
            child: const Text('Copy details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Upload content',
      subtitle: 'Download center file',
      child: _loadingTypes
          ? const SiLoadingBlock(message: 'Loading content types…')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_types.isEmpty)
                    Card(
                      elevation: 0,
                      color: AppColors.surfaceWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No content types are configured on the server. Add types in the web admin, then refresh.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Content type',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: _contentTypeId,
                      isExpanded: true,
                      decoration: SiChrome.inputDecoration(
                        context,
                        labelText: 'Category',
                      ),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem<int>(
                              value: t.id,
                              child: Text(
                                t.name.isNotEmpty ? t.name : 'Type #${t.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _uploading
                          ? null
                          : (v) => setState(() => _contentTypeId = v),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickFile,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Choose file'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppColors.primaryBlue.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_picked != null)
                      Card(
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: AppColors.accentTeal.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: AppColors.primaryBlue.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _picked!.name,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_picked!.size > 0)
                                Text(
                                  _formatSize(_picked!.size),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _uploading || _picked == null || _contentTypeId == null
                          ? null
                          : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(_uploading ? 'Uploading…' : 'Upload to library'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Allowed: documents, images, common audio/video, and zip (max 25 MB). '
                      'The file appears in Content Library after a successful upload.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
