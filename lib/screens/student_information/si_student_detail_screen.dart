import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_ui.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
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
    final d =
        await StudentInformationRepository.getStudentDetail(widget.studentId);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
      if (d == null) _error = 'Could not load student.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _data != null && _data!.displayName.isNotEmpty
        ? _data!.displayName
        : 'Profile & contact details';

    return SiThemedPageScaffold(
      title: 'Student profile',
      subtitle: _loading ? 'Loading…' : subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading profile…')
          : _data == null
              ? SiEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Unable to load',
                  message: _error ?? 'Unknown error',
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                    children: [
                      _heroBanner(context, _data!),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionCard(
                              context,
                              'Enrollment',
                              [
                                _kv('Admission no', _data!.admissionNo),
                                _kv('Roll no', _data!.rollNo),
                                _kv('Admission date', _data!.admissionDate),
                                _kv('Class', _data!.className),
                                _kv('Section', _data!.sectionName),
                                _kv('Category', _data!.category),
                                _kv('House', _data!.houseName),
                                _kv('Status', _data!.isActive),
                                _kv('Login username', _data!.loginUsername),
                              ],
                            ),
                            _sectionCard(
                              context,
                              'Student',
                              [
                                _kv('DOB', _data!.dob),
                                _kv('Gender', _data!.gender),
                                _kv('Blood group', _data!.bloodGroup),
                                _kv('Religion', _data!.religion),
                                _kv('Caste', _data!.cast),
                                _kv('RTE', _data!.rte),
                                _kv('About', _data!.about),
                              ],
                            ),
                            _sectionCard(
                              context,
                              'Contact',
                              [
                                _kv('Mobile', _data!.mobileno),
                                _kv('Email', _data!.email),
                                _kv('City / State', _cityState(_data!)),
                                _kv('PIN', _data!.pincode),
                                _kv('Current address', _data!.currentAddress),
                                _kv('Permanent address', _data!.permanentAddress),
                                _kv('Previous school', _data!.previousSchool),
                              ],
                            ),
                            _sectionCard(
                              context,
                              'Parents & guardian',
                              [
                                _kv('Father', _data!.fatherName),
                                _kv('Father phone', _data!.fatherPhone),
                                _kv('Father occupation', _data!.fatherOccupation),
                                _kv('Mother', _data!.motherName),
                                _kv('Mother phone', _data!.motherPhone),
                                _kv('Mother occupation', _data!.motherOccupation),
                                _kv('Guardian is', _data!.guardianIs),
                                _kv('Guardian', _data!.guardianName),
                                _kv('Relation', _data!.guardianRelation),
                                _kv('Guardian phone', _data!.guardianPhone),
                                _kv('Guardian email', _data!.guardianEmail),
                                _kv('Guardian address', _data!.guardianAddress),
                                _kv('Guardian occupation', _data!.guardianOccupation),
                              ],
                            ),
                            if (_data!.isActive == 'no')
                              _sectionCard(
                                context,
                                'Inactive',
                                [
                                  _kv('Disable reason', _data!.disReason),
                                  _kv('Disable note', _data!.disNote),
                                  _kv('Disabled at', _data!.disableAt),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _cityState(SiStudentDetailModel s) {
    final parts = <String>[];
    if (s.city.isNotEmpty) parts.add(s.city);
    if (s.state.isNotEmpty) parts.add(s.state);
    return parts.join(', ');
  }

  Widget _heroBanner(BuildContext context, SiStudentDetailModel s) {
    final imgUrl = SiUi.studentImageUrl(s.image.isEmpty ? null : s.image);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.12),
            AppColors.accentTeal.withOpacity(0.14),
            AppColors.secondaryPurple.withOpacity(0.08),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Container(
                width: 100,
                height: 100,
                color: AppColors.surfaceWhite,
                child: imgUrl != null
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppColors.primaryBlue.withOpacity(0.7),
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: AppColors.primaryBlue.withOpacity(0.7),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String heading,
    List<Widget> children,
  ) {
    final nonEmpty = <Widget>[];
    for (final w in children) {
      if (w is! SizedBox) nonEmpty.add(w);
    }
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: 0,
        color: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    heading,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...nonEmpty,
            ],
          ),
        ),
      ),
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
