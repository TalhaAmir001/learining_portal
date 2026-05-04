import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/share_content/dc_create_share_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class DcShareContentsScreen extends StatefulWidget {
  const DcShareContentsScreen({super.key});

  @override
  State<DcShareContentsScreen> createState() => _DcShareContentsScreenState();
}

class _DcShareContentsScreenState extends State<DcShareContentsScreen> {
  Future<List<DcShareContentModel>>? _future;
  bool _depsReady = false;

  Future<List<DcShareContentModel>> _loadShares() {
    final staffId = context.read<AuthProvider>().portalStaffId ?? 0;
    // Match web: only batches created by the logged-in staff (not all admins’ shares).
    return ShareContentRepository.getShareContents(
      createdBy: staffId > 0 ? staffId : null,
      listAll: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _future = _loadShares();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadShares();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Shared content',
      subtitle: 'Distribution batches',
      actions: [
        IconButton(
          tooltip: 'New share',
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => const DcCreateShareScreen(),
              ),
            );
            if (!context.mounted) return;
            if (created == true) {
              await _reload();
            }
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _reload();
            if (context.mounted) SiChrome.showMessage(context, 'Refreshed');
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
      child: FutureBuilder<List<DcShareContentModel>>(
        future: _future,
        builder: (context, snap) {
          if (_future == null || snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading shares…');
          }
          final list = snap.data ?? [];
          final staffId = context.read<AuthProvider>().portalStaffId ?? 0;
          if (staffId <= 0) {
            return const SiEmptyState(
              icon: Icons.badge_outlined,
              title: 'Staff account required',
              message:
                  'Shared content lists only batches you created. Sign in as teacher or admin with a linked staff id.',
            );
          }
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.ios_share_outlined,
              title: 'No shared batches yet',
              message: 'Use + to share library files (same flow as the web admin).',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                final meta = [
                  if (s.sendTo.isNotEmpty) 'To: ${s.sendTo}',
                  if (s.shareDate.isNotEmpty) 'From ${s.shareDate}',
                  if (s.validUpto.isNotEmpty) 'Until ${s.validUpto}',
                  if (s.createdByName.isNotEmpty) s.createdByName,
                ].join(' · ');
                return SiResultCard(
                  title: s.title.isNotEmpty ? s.title : 'Share #${s.id}',
                  subtitle: meta.isNotEmpty ? meta : '—',
                  leadingIcon: Icons.ios_share_rounded,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _DcShareDetailPage(model: s),
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

class _DcShareDetailPage extends StatelessWidget {
  const _DcShareDetailPage({required this.model});

  final DcShareContentModel model;

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: model.title.isNotEmpty ? model.title : 'Share detail',
      subtitle: model.sendTo.isNotEmpty ? model.sendTo : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SiKeyValueTile(label: 'Send to', value: model.sendTo),
          SiKeyValueTile(label: 'Share date', value: model.shareDate),
          SiKeyValueTile(label: 'Valid until', value: model.validUpto),
          SiKeyValueTile(label: 'Created by', value: model.createdByName),
          if (model.employeeId.isNotEmpty)
            SiKeyValueTile(label: 'Employee ID', value: model.employeeId),
          SiKeyValueTile(label: 'Created at', value: model.createdAt),
          SiKeyValueTile(
            label: 'Description',
            value: model.description.isNotEmpty ? model.description : '—',
          ),
        ],
      ),
    );
  }
}
