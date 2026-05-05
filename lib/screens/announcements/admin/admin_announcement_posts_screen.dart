import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/announcement/announcement_models.dart';
import 'package:learining_portal/network/domain/announcement_feed_repository.dart';
import 'package:learining_portal/screens/announcements/admin/admin_announcement_edit_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminAnnouncementPostsScreen extends StatefulWidget {
  const AdminAnnouncementPostsScreen({super.key});

  @override
  State<AdminAnnouncementPostsScreen> createState() =>
      _AdminAnnouncementPostsScreenState();
}

class _AdminAnnouncementPostsScreenState extends State<AdminAnnouncementPostsScreen> {
  bool _loading = true;
  String? _error;
  List<AnnouncementPost> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await AnnouncementFeedRepository.getForAdmin();
      if (!payload.success) {
        _error = payload.error ?? 'Failed to load announcements.';
        _items = const [];
      } else {
        _items = payload.items;
        if (_items.isEmpty) {
          _error = 'No posts yet.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _items = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEditor({AnnouncementPost? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAnnouncementEditScreen(existing: existing),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(AnnouncementPost p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text('This will delete "${p.title.isEmpty ? 'Announcement' : p.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AnnouncementFeedRepository.deleteAdmin(id: p.id);
      if (!mounted) return;
      if (r['success'] == true) {
        await _load();
      } else {
        SiChrome.showMessage(context, (r['error'] ?? 'Delete failed').toString());
      }
    } catch (e) {
      if (!mounted) return;
      SiChrome.showMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Announcement posts',
      subtitle: 'Admin',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          color: Colors.white,
          onPressed: _loading ? null : () => _openEditor(),
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _items.isEmpty
              ? SiEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No posts',
                  message: _error,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final p = _items[i];
                      final title = p.title.isNotEmpty ? p.title : 'Announcement';
                      final audience = [
                        if (p.className.isNotEmpty) p.className,
                        if (p.sectionName.isNotEmpty) p.sectionName,
                      ].join(' · ');
                      final subtitle = [
                        if (audience.isNotEmpty) audience,
                        p.isPublished ? 'Published' : 'Draft',
                        p.authorName,
                      ].join(' • ');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.campaign_rounded, color: AppColors.primaryBlue),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openEditor(existing: p),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(p),
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

