import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
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
                (SiCategoryModel e) => ListTile(
                  title: Text(e.category.isEmpty ? '(unnamed)' : e.category),
                  subtitle: Text('ID: ${e.id}'),
                ),
              )
              .toList();
          break;
        case SiReferenceKind.houses:
          final list = await StudentInformationRepository.getSchoolHouses();
          _rows = list
              .map(
                (SiSchoolHouseModel e) => ListTile(
                  title: Text(e.houseName.isEmpty ? '(unnamed)' : e.houseName),
                  subtitle: Text('ID: ${e.id}'),
                ),
              )
              .toList();
          break;
        case SiReferenceKind.reasons:
          final list = await StudentInformationRepository.getDisableReasons();
          _rows = list
              .map(
                (SiDisableReasonModel e) => ListTile(
                  title: Text(e.reason.isEmpty ? '(empty)' : e.reason),
                  subtitle: Text('ID: ${e.id}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: _rows),
                ),
    );
  }
}
