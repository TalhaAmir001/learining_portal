import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/share_content/dc_create_share_screen.dart';
import 'package:learining_portal/screens/share_content/dc_upload_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class DcUploadContentsScreen extends StatefulWidget {
  const DcUploadContentsScreen({super.key});

  @override
  State<DcUploadContentsScreen> createState() => _DcUploadContentsScreenState();
}

class _DcUploadContentsScreenState extends State<DcUploadContentsScreen> {
  Future<List<DcUploadContentModel>>? _future;
  bool _depsReady = false;

  /// Same as web admin Content list: `upload_by` = logged-in staff id.
  Future<List<DcUploadContentModel>> _loadLibrary() {
    final staffId = context.read<AuthProvider>().portalStaffId ?? 0;
    if (staffId <= 0) {
      return Future.value([]);
    }
    return ShareContentRepository.getUploadContents(limit: 300, uploadBy: staffId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _future = _loadLibrary();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadLibrary();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Content Library',
      subtitle: 'Recent uploads',
      actions: [
        IconButton(
          tooltip: 'Share from library',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DcCreateShareScreen(),
              ),
            );
          },
          icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _reload();
            if (context.mounted) {
              SiChrome.showMessage(context, 'Refreshed');
            }
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
      child: FutureBuilder<List<DcUploadContentModel>>(
        future: _future,
        builder: (context, snap) {
          if (_future == null || snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading library…');
          }
          final list = snap.data ?? [];
          final staffId = context.read<AuthProvider>().portalStaffId ?? 0;
          if (staffId <= 0) {
            return const SiEmptyState(
              icon: Icons.badge_outlined,
              title: 'Staff account required',
              message:
                  'Content library lists only your uploads (same as the web). Sign in as teacher or admin with a linked staff id.',
            );
          }
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No uploads yet',
              message: 'Upload files from this app or the web download center; only your items appear here.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final u = list[i];
                final sub = [
                  if (u.contentTypeName.isNotEmpty) u.contentTypeName,
                  if (u.fileSize.isNotEmpty) u.fileSize,
                  if (u.createdAt.isNotEmpty) u.createdAt,
                ].join(' · ');
                return SiResultCard(
                  title: u.realName.isNotEmpty ? u.realName : 'Untitled',
                  subtitle: sub.isNotEmpty ? sub : '—',
                  leadingIcon: Icons.insert_drive_file_rounded,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DcUploadDetailScreen(item: u),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
