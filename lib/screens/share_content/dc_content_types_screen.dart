import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class DcContentTypesScreen extends StatefulWidget {
  const DcContentTypesScreen({super.key});

  @override
  State<DcContentTypesScreen> createState() => _DcContentTypesScreenState();
}

class _DcContentTypesScreenState extends State<DcContentTypesScreen> {
  late Future<List<DcContentTypeModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShareContentRepository.getContentTypes();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ShareContentRepository.getContentTypes();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Content types',
      subtitle: 'Download center categories',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _reload();
            if (context.mounted) SiChrome.showMessage(context, 'Refreshed');
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
      child: FutureBuilder<List<DcContentTypeModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading types…');
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const SiEmptyState(
              icon: Icons.label_off_outlined,
              title: 'No content types',
              message: 'Configure types in the web admin.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final active = t.isActive == '1' || t.isActive.toLowerCase() == 'yes';
                return SiReadOnlyListCard(
                  title: t.name.isNotEmpty ? t.name : 'Type #${t.id}',
                  meta: [
                    if (t.description.isNotEmpty) t.description,
                    active ? 'Active' : 'Inactive',
                  ].join(' · '),
                  icon: Icons.category_rounded,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
