import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/timetable_models.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Renders timetable entries for daily (flat list) or weekly (grouped by day).
class AcTimetableListView extends StatelessWidget {
  const AcTimetableListView({
    super.key,
    required this.payload,
    required this.weekly,
    this.singleDay,
    this.onEntryTap,
    this.emptyMessage = 'No periods found.',
  });

  final AcTimetablePayload payload;
  final bool weekly;
  /// When [weekly] is false, restrict to this weekday (must match API `day` param).
  final String? singleDay;
  final void Function(AcTimetableEntry entry)? onEntryTap;
  final String emptyMessage;

  List<String> get _dayOrder {
    if (payload.dayOrder.isNotEmpty) return payload.dayOrder;
    return AcademicsWeekdayFallback.order;
  }

  @override
  Widget build(BuildContext context) {
    if (!payload.success) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            payload.error ?? 'Failed to load timetable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ),
      );
    }

    if (weekly) {
      final by = payload.byDay;
      if (by == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final keys = _dayOrder.where((d) => by.containsKey(d)).toList();
      if (keys.isEmpty) {
        for (final k in by.keys) {
          if (!keys.contains(k)) keys.add(k);
        }
      }
      if (keys.isEmpty) {
        return _empty(context);
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final day = keys[i];
          final entries = by[day] ?? const <AcTimetableEntry>[];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.08)),
            ),
            child: ExpansionTile(
              initiallyExpanded: entries.isNotEmpty,
              title: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: Text('${entries.length} period${entries.length == 1 ? '' : 's'}'),
              children: entries.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No classes', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    ]
                  : entries.map((e) => _tile(context, e)).toList(),
            ),
          );
        },
      );
    }

    final list = payload.entries;
    if (list.isEmpty) {
      return _empty(context);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, i) => _tile(context, list[i]),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AcTimetableEntry e) {
    return ListTile(
      onTap: onEntryTap == null ? null : () => onEntryTap!(e),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
        child: const Icon(Icons.schedule_rounded, color: AppColors.primaryBlue, size: 22),
      ),
      title: Text(
        e.subjectName.isNotEmpty ? e.subjectName : 'Subject',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        weekly
            ? '${e.className} ${e.sectionName} · ${e.timeFrom}–${e.timeTo} · ${e.roomNo}'
            : '${e.timeFrom}–${e.timeTo} · ${e.roomNo} · ${e.staffDisplayName}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// If API omits `day_order`, use ISO weekday order.
abstract final class AcademicsWeekdayFallback {
  static const List<String> order = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
}
