import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_ui.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiStudentDetailScreen extends StatefulWidget {
  const SiStudentDetailScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<SiStudentDetailScreen> createState() => _SiStudentDetailScreenState();
}

class _SiStudentDetailScreenState extends State<SiStudentDetailScreen> {
  SiStudentDetailModel? _data;
  bool _loading = true;
  String? _error;

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
    final d = await StudentInformationRepository.getStudentDetail(widget.studentId);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
      if (d == null) _error = 'Could not load student.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student profile'),
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
          : _data == null
              ? Center(child: Text(_error ?? 'Unknown error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _body(_data!),
                ),
    );
  }

  Widget _body(SiStudentDetailModel s) {
    final imgUrl = SiUi.studentImageUrl(s.image.isEmpty ? null : s.image);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipOval(
            child: Container(
              width: 96,
              height: 96,
              color: AppColors.accentTeal.withOpacity(0.2),
              child: imgUrl != null
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: AppColors.primaryBlue,
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${s.className} — ${s.sectionName}',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const Divider(height: 32),
        _kv('Admission no', s.admissionNo),
        _kv('Roll no', s.rollNo),
        _kv('Admission date', s.admissionDate),
        _kv('DOB', s.dob),
        _kv('Gender', s.gender),
        _kv('Category', s.category),
        _kv('House', s.houseName),
        _kv('Blood group', s.bloodGroup),
        _kv('Status', s.isActive),
        _kv('Login username', s.loginUsername),
        const Divider(height: 24),
        _kv('Mobile', s.mobileno),
        _kv('Email', s.email),
        _kv('City / State', '${s.city}${s.city.isNotEmpty && s.state.isNotEmpty ? ', ' : ''}${s.state}'),
        _kv('PIN', s.pincode),
        _kv('Current address', s.currentAddress),
        _kv('Permanent address', s.permanentAddress),
        _kv('Previous school', s.previousSchool),
        const Divider(height: 24),
        _kv('Father', s.fatherName),
        _kv('Father phone', s.fatherPhone),
        _kv('Father occupation', s.fatherOccupation),
        _kv('Mother', s.motherName),
        _kv('Mother phone', s.motherPhone),
        _kv('Mother occupation', s.motherOccupation),
        const Divider(height: 24),
        _kv('Guardian is', s.guardianIs),
        _kv('Guardian', s.guardianName),
        _kv('Relation', s.guardianRelation),
        _kv('Guardian phone', s.guardianPhone),
        _kv('Guardian email', s.guardianEmail),
        _kv('Guardian address', s.guardianAddress),
        _kv('Guardian occupation', s.guardianOccupation),
        const Divider(height: 24),
        _kv('Religion', s.religion),
        _kv('Caste', s.cast),
        _kv('RTE', s.rte),
        _kv('About', s.about),
        if (s.isActive == 'no') ...[
          const Divider(height: 24),
          _kv('Disable reason', s.disReason),
          _kv('Disable note', s.disNote),
          _kv('Disabled at', s.disableAt),
        ],
      ],
    );
  }

  Widget _kv(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
