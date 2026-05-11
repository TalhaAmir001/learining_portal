import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Compact chip that shows the guardian's currently selected child and opens a
/// bottom-sheet picker to switch between linked children. Designed to live in
/// header / app-bar areas — width is intrinsic so it can sit next to a title.
///
/// Renders nothing for non-guardian users or when fewer than 2 children are
/// linked (the `>= 2` rule from the plan).
class ChildPickerChip extends StatelessWidget {
  const ChildPickerChip({super.key, this.compact = false});

  /// When true, the chip uses tighter padding for tight headers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.userType != UserType.guardian) {
          return const SizedBox.shrink();
        }
        final children = auth.linkedChildren;
        if (children.length < 2) {
          return const SizedBox.shrink();
        }

        final selected = auth.selectedChild;
        final label = selected?.fullName ?? 'Pick child';

        return Material(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => _openPicker(context, auth),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPicker(BuildContext context, AuthProvider auth) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => _ChildPickerSheet(
        children: auth.linkedChildren,
        selectedId: auth.selectedChildId,
        onPick: (child) async {
          Navigator.pop(sheetCtx);
          if (auth.selectedChildId == child.studentId) return;
          final ok = await auth.setSelectedChild(child.studentId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: ok ? AppColors.primaryBlue : Colors.red,
              content: Text(
                ok
                    ? '${child.fullName} is now active.'
                    : 'Could not switch active child. Try again.',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChildPickerSheet extends StatelessWidget {
  const _ChildPickerSheet({
    required this.children,
    required this.selectedId,
    required this.onPick,
  });

  final List<ParentChild> children;
  final int? selectedId;
  final void Function(ParentChild child) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              'Pick active child',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The rest of the app will scope to this child.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = children[i];
                  final isActive = c.studentId == selectedId;
                  return _ChildPickerRow(
                    child: c,
                    isActive: isActive,
                    onTap: () => onPick(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildPickerRow extends StatelessWidget {
  const _ChildPickerRow({
    required this.child,
    required this.isActive,
    required this.onTap,
  });

  final ParentChild child;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isActive
        ? AppColors.primaryBlue
        : AppColors.textSecondary.withOpacity(0.14);
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isActive ? 1.6 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (child.admissionNo.isNotEmpty)
                          'Adm: ${child.admissionNo}',
                        if (child.classLabel.isNotEmpty) child.classLabel,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isActive
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
