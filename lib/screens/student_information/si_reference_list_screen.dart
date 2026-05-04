import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

enum SiReferenceKind { categories, houses, reasons }

class SiReferenceListScreen extends StatefulWidget {
  const SiReferenceListScreen({super.key, required this.kind});

  final SiReferenceKind kind;

  @override
  State<SiReferenceListScreen> createState() => _SiReferenceListScreenState();
}

class _SiReferenceListScreenState extends State<SiReferenceListScreen> {
  bool _loading = true;
  String? _error;
  List<Widget> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _title {
    switch (widget.kind) {
      case SiReferenceKind.categories:
        return 'Student Categories';
      case SiReferenceKind.houses:
        return 'Student Houses';
      case SiReferenceKind.reasons:
        return 'Disable Reasons';
    }
  }

  String get _subtitle {
    switch (widget.kind) {
      case SiReferenceKind.categories:
        return 'Fee and demographic categories';
      case SiReferenceKind.houses:
        return 'House names for student grouping';
      case SiReferenceKind.reasons:
        return 'Reasons used when disabling students';
    }
  }

  IconData get _listIcon {
    switch (widget.kind) {
      case SiReferenceKind.categories:
        return Icons.category_rounded;
      case SiReferenceKind.houses:
        return Icons.house_rounded;
      case SiReferenceKind.reasons:
        return Icons.rule_folder_rounded;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.kind) {
        case SiReferenceKind.categories:
          final list = await StudentInformationRepository.getCategories();
          _rows = list
              .map(
                (SiCategoryModel e) => SiReadOnlyListCard(
                  title: e.category.isEmpty ? '(unnamed)' : e.category,
                  meta: 'ID ${e.id}',
                  icon: _listIcon,
                ),
              )
              .toList();
          break;
        case SiReferenceKind.houses:
          final list = await StudentInformationRepository.getSchoolHouses();
          _rows = list
              .map(
                (SiSchoolHouseModel e) => SiReadOnlyListCard(
                  title: e.houseName.isEmpty ? '(unnamed)' : e.houseName,
                  meta: 'ID ${e.id}',
                  icon: _listIcon,
                ),
              )
              .toList();
          break;
        case SiReferenceKind.reasons:
          final list = await StudentInformationRepository.getDisableReasons();
          _rows = list
              .map(
                (SiDisableReasonModel e) => SiReadOnlyListCard(
                  title: e.reason.isEmpty ? '(empty)' : e.reason,
                  meta: 'ID ${e.id}',
                  icon: _listIcon,
                ),
              )
              .toList();
          break;
      }
      if (_rows.isEmpty) {
        _error = 'No records returned.';
      }
    } catch (e) {
      _error = e.toString();
      _rows = [];
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: _title,
      subtitle: _subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _error != null && _rows.isEmpty
              ? SiEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Nothing to show',
                  message: _error!,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: _rows,
                  ),
                ),
    );
  }
}
