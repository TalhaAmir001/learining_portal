import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/announcement/announcement_models.dart';
import 'package:learining_portal/network/domain/announcement_feed_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/announcements/announcement_post_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class AnnouncementPostsScreen extends StatefulWidget {
  const AnnouncementPostsScreen({super.key});

  @override
  State<AnnouncementPostsScreen> createState() => _AnnouncementPostsScreenState();
}

class _AnnouncementPostsScreenState extends State<AnnouncementPostsScreen> {
  bool _loading = true;
  String? _error;
  List<AnnouncementPost> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _studentIdFromAuth(AuthProvider auth) {
    if (auth.userType != UserType.student) return null;
    final raw = auth.currentUser?.additionalData?['id'] ?? auth.currentUser?.id;
    final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (n != null && n > 0) return n;
    return null;
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final studentId = _studentIdFromAuth(auth);
    if (studentId == null) {
      setState(() {
        _loading = false;
        _error = 'Announcements are available for student accounts.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await AnnouncementFeedRepository.getForStudent(
        studentId: studentId,
      );
      if (!payload.success) {
        _error = payload.error ?? 'Failed to load announcements.';
        _items = const [];
      } else {
        _items = payload.items;
        if (_items.isEmpty) {
          _error = 'No announcements yet.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _items = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Announcements',
      subtitle: 'School updates',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _items.isEmpty
              ? SiEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Nothing to show',
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
                      final preview = p.body.isNotEmpty
                          ? p.body.replaceAll(RegExp(r'\\s+'), ' ').trim()
                          : 'Tap to view';
                      return SiResultCard(
                        title: title,
                        subtitle: '${p.authorName}\n$preview',
                        leadingIcon: Icons.campaign_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnnouncementPostDetailScreen(post: p),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

