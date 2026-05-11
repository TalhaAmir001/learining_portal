import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/zoom_live_classes/zoom_live_classes_models.dart';
import 'package:learining_portal/network/domain/zoom_live_classes_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart' show AuthProvider, UserType;
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_user_ids.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ZlcJoinDetailScreen extends StatefulWidget {
  const ZlcJoinDetailScreen({
    super.key,
    required this.conferenceId,
    this.openFeedbackAfter = false,
  });

  final int conferenceId;
  final bool openFeedbackAfter;

  @override
  State<ZlcJoinDetailScreen> createState() => _ZlcJoinDetailScreenState();
}

class _ZlcJoinDetailScreenState extends State<ZlcJoinDetailScreen> {
  ZlcJoinLinkModel? _link;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final staffId = auth.portalStaffId ?? int.tryParse(auth.currentUser?.id ?? '') ?? 0;
    final link = await ZoomLiveClassesRepository.getJoinLink(
      conferenceId: widget.conferenceId,
      viewerStaffId: auth.userType == UserType.teacher || auth.userType == UserType.admin
          ? staffId
          : 0,
    );
    if (!mounted) return;
    setState(() {
      _link = link;
      _error = link == null ? 'Could not load join link.' : null;
      _loading = false;
    });
    if (widget.openFeedbackAfter && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeOpenFeedback(context.read<AuthProvider>());
      });
    }
  }

  Future<void> _maybeOpenFeedback(AuthProvider auth) async {
    final sid = zlcPortalStudentId(auth);
    if (sid == null) return;
    final meta = await ZoomLiveClassesRepository.getLiveFeedbackMeta(
      studentId: sid,
      conferenceId: widget.conferenceId,
    );
    if (!mounted) return;
    final can = meta['can_submit'] == true;
    if (!can) {
      SiChrome.showMessage(context, 'Feedback is not available for this class yet.');
      return;
    }
    final existing = meta['feedback'] as Map<String, dynamic>?;
    var rating = (existing?['behavior_rating'] as num?)?.toInt() ?? 3;
    final commentCtrl = TextEditingController(text: existing?['comment']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var r = rating;
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Live class feedback'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rating: $r'),
                Slider(
                  value: r.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$r',
                  onChanged: (v) => setLocal(() => r = v.round()),
                ),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comment (optional)'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  rating = r;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true && mounted) {
      final res = await ZoomLiveClassesRepository.saveLiveFeedback(
        studentId: sid,
        conferenceId: widget.conferenceId,
        rating: rating,
        comment: commentCtrl.text,
      );
      if (!mounted) return;
      SiChrome.showMessage(
        context,
        res['success'] == true ? 'Feedback saved.' : (res['error']?.toString() ?? 'Save failed'),
      );
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _trackThenOpen(String? url) async {
    final auth = context.read<AuthProvider>();
    final staffId = auth.portalStaffId ?? int.tryParse(auth.currentUser?.id ?? '') ?? 0;
    final stu = zlcPortalStudentId(auth);
    if (stu != null) {
      await ZoomLiveClassesRepository.trackJoin(
        conferenceId: widget.conferenceId,
        studentId: stu,
      );
    } else if (staffId > 0) {
      await ZoomLiveClassesRepository.trackJoin(
        conferenceId: widget.conferenceId,
        staffId: staffId,
      );
    }
    await _openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Join session',
      subtitle: 'Opens in Zoom app or browser',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _link?.title ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(_link?.date ?? '', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Host: ${_link?.hostDisplayName ?? ''}'),
                  const SizedBox(height: 16),
                  if ((_link?.password ?? '').isNotEmpty)
                    Text('Password: ••••••••', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _trackThenOpen(_link?.joinUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Join'),
                  ),
                  if ((_link?.startUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _trackThenOpen(_link?.startUrl),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('Start (host)'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
