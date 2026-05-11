import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/zoom_live_classes/zoom_live_classes_models.dart';
import 'package:learining_portal/network/domain/zoom_live_classes_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_join_detail_screen.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_user_ids.dart';
import 'package:provider/provider.dart';

class ZlcLiveClassesListScreen extends StatefulWidget {
  const ZlcLiveClassesListScreen({super.key});

  @override
  State<ZlcLiveClassesListScreen> createState() => _ZlcLiveClassesListScreenState();
}

class _ZlcLiveClassesListScreenState extends State<ZlcLiveClassesListScreen> {
  List<ZlcConferenceListItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    List<ZlcConferenceListItem> list = [];
    if (auth.userType == UserType.admin) {
      list = await ZoomLiveClassesRepository.getLiveClasses(role: 'admin');
    } else if (auth.userType == UserType.teacher) {
      final sid = user?.portalStaffId ?? int.tryParse(user?.id ?? '');
      list = await ZoomLiveClassesRepository.getLiveClasses(
        role: 'teacher',
        staffId: sid ?? 0,
      );
    } else {
      final stu = zlcPortalStudentId(auth);
      if (stu != null) {
        list = await ZoomLiveClassesRepository.getLiveClasses(
          role: auth.userType == UserType.guardian ? 'guardian' : 'student',
          studentId: stu,
        );
      }
    }
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Live classes',
      subtitle: 'Tap a row to join',
      actions: [
        IconButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No live classes found.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = _items[i];
                final sec = it.sections
                    .map((s) => '${s.className} ${s.sectionName}')
                    .join(' · ');
                return Card(
                  child: ListTile(
                    title: Text(it.title),
                    subtitle: Text(
                      '${it.date}\n${sec.isEmpty ? '' : sec}',
                      maxLines: 3,
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ZlcJoinDetailScreen(conferenceId: it.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
