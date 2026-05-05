import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/timetable_models.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Shared helpers for Academics timetable screens.
abstract final class AcademicsUi {
  static const List<String> englishWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Calendar date in the current week that matches [dayName] (Portal weekday / timetable `day` column).
  static DateTime dateForEnglishWeekday(String dayName) {
    final want = _weekdayFromEnglish(dayName);
    if (want == null) return DateTime.now();
    final d = DateTime.now();
    return d.add(Duration(days: want - d.weekday));
  }

  static int? _weekdayFromEnglish(String dayName) {
    switch (dayName.trim()) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  static List<AcSubjectGroupSubjectOption> subjectOptionsForClassSection(
    AcTimetableMeta meta,
    int classId,
    int sectionId,
  ) {
    final groupIds = meta.classSectionSubjectGroups
        .where((e) => e.classId == classId && e.sectionId == sectionId)
        .map((e) => e.subjectGroupId)
        .toSet();
    final list = meta.subjectGroupSubjects.where((e) => groupIds.contains(e.subjectGroupId)).toList();
    list.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return list;
  }

  static Future<void> showTimetableEntrySheet(
    BuildContext context, {
    required AcTimetableEntry entry,
    required bool isAdmin,
    required VoidCallback onMarkAttendance,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.32,
          maxChildSize: 0.9,
          builder: (_, scroll) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.subjectName.isNotEmpty ? entry.subjectName : 'Period',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${entry.className} · ${entry.sectionName} · ${entry.day}',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.timeFrom} – ${entry.timeTo} · Room ${entry.roomNo}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.staffDisplayName,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onMarkAttendance();
                    },
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Mark attendance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEdit == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onEdit();
                            },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit slot'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onDelete == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onDelete();
                            },
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                      label: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
