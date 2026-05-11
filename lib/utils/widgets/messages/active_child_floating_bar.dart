// lib/utils/widgets/messages/active_child_floating_bar.dart
//
// Floating bar shown directly under the chat screen's gradient app bar
// whenever a parent/guardian is involved in the conversation. It surfaces
// the parent's currently active child (name + admission no.) so both sides
// always know which child the chat is about.
//
// Two visibility modes:
//
//   1. Self-guardian view  — the logged-in user IS a guardian.
//      • Source: `AuthProvider.selectedChild` (already in memory).
//      • Tappable when the parent has >1 linked child → opens MyChildrenScreen.
//
//   2. Staff-with-parent view — the logged-in user is teacher/admin AND the
//      other chat participant is a guardian (typical for "Support" threads
//      after admin claim).
//      • Source: one-shot fetch of /mobile_apis/get_app_parent_summary.php,
//        keyed by `otherUser.uid` (the parent's `app_parents.id`).
//      • Read-only — no Switch action (staff don't pick the parent's child).
//
// In every other case the widget collapses to `SizedBox.shrink()` so it
// costs nothing in non-parent chats.

import 'package:flutter/material.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/domain/parent_link_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/parent_children/my_children_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:provider/provider.dart';

class ActiveChildFloatingBar extends StatefulWidget {
  /// The other side of the chat. Used by the staff-with-parent flow to
  /// identify which `app_parents` row to look up. Leave null when the host
  /// screen doesn't know the counterparty yet (no bar rendered in that case
  /// for the staff path).
  final UserModel? otherUser;

  /// When true (default), self-guardian view becomes tappable for switching.
  /// Disable if the host wants a purely informational chip.
  final bool allowSwitch;

  const ActiveChildFloatingBar({
    super.key,
    this.otherUser,
    this.allowSwitch = true,
  });

  @override
  State<ActiveChildFloatingBar> createState() => _ActiveChildFloatingBarState();
}

class _ActiveChildFloatingBarState extends State<ActiveChildFloatingBar> {
  // Cache for the staff-side fetch. Keyed by parent id so we re-fetch if the
  // host swaps the otherUser (rare, but defensive).
  int? _fetchedForParentId;
  ParentChild? _fetchedChild;
  bool _isFetching = false;

  bool _shouldFetchStaffSide(AuthProvider auth) {
    if (auth.userType == UserType.guardian) return false;
    final other = widget.otherUser;
    if (other == null) return false;
    if (other.uid == supportUserId) return false; // Support sentinel
    if (other.userType != UserType.guardian) return false;
    final id = int.tryParse(other.uid);
    return id != null && id > 0;
  }

  Future<void> _fetchStaffSide(int parentId) async {
    if (_isFetching || _fetchedForParentId == parentId) return;
    _isFetching = true;
    _fetchedForParentId = parentId;

    final child = await ParentLinkRepository.getActiveChildForParent(
      parentId: parentId,
    );

    if (!mounted) return;
    setState(() {
      _fetchedChild = child;
      _isFetching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watching the auth provider so live updates (e.g. parent switches their
    // active child while staff is viewing) eventually surface — though for
    // the staff side the cached fetch keeps the bar stable.
    final auth = context.watch<AuthProvider>();

    // ── Mode 1: logged-in user is a guardian → use in-memory state ───────
    if (auth.userType == UserType.guardian) {
      final child = _resolveSelfActiveChild(auth);
      if (child == null) return const SizedBox.shrink();
      return _ActiveChildBarBody(
        child: child,
        showSwitchAction:
            widget.allowSwitch && auth.linkedChildren.length > 1,
        leadingLabel: 'Chatting on behalf of',
      );
    }

    // ── Mode 2: staff chatting with a parent → fetch once, cache ─────────
    if (_shouldFetchStaffSide(auth)) {
      final parentId = int.parse(widget.otherUser!.uid);
      if (_fetchedForParentId != parentId) {
        // Defer to post-frame so we don't setState during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchStaffSide(parentId);
        });
        return _buildLoadingSkeleton();
      }
      final child = _fetchedChild;
      if (child == null) return const SizedBox.shrink();
      return _ActiveChildBarBody(
        child: child,
        showSwitchAction: false,
        leadingLabel: 'Conversation about',
      );
    }

    return const SizedBox.shrink();
  }

  /// For the guardian themselves. Picks the explicit selection first, then
  /// the single-child shortcut, then resolves via `effectiveChildId`.
  static ParentChild? _resolveSelfActiveChild(AuthProvider auth) {
    final picked = auth.selectedChild;
    if (picked != null) return picked;
    if (auth.linkedChildren.length == 1) return auth.linkedChildren.first;
    final id = auth.effectiveChildId;
    if (id == null) return null;
    for (final c in auth.linkedChildren) {
      if (c.studentId == id) return c;
    }
    return null;
  }

  /// Skeleton placeholder while the staff-side fetch is in flight. Keeps
  /// the bar height stable so chat layout doesn't jump when the data lands.
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryBlue.withOpacity(0.06),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withOpacity(0.08),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonLine(width: 90, height: 8),
                  const SizedBox(height: 6),
                  _SkeletonLine(width: 140, height: 12),
                ],
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ActiveChildBarBody extends StatelessWidget {
  final ParentChild child;
  final bool showSwitchAction;
  final String leadingLabel;

  const _ActiveChildBarBody({
    required this.child,
    required this.showSwitchAction,
    required this.leadingLabel,
  });

  void _openMyChildren(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyChildrenScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admission = child.admissionNo.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: showSwitchAction ? () => _openMyChildren(context) : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  _AvatarBadge(name: child.fullName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leadingLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          child.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (admission.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          _AdmissionPill(admission: admission),
                        ],
                      ],
                    ),
                  ),
                  if (showSwitchAction) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Switch',
                            style: TextStyle(
                              color: AppColors.accentTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.accentTeal,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular avatar showing the child's first initial. Uses the brand
/// gradient so the bar visually ties to the gradient header above it.
class _AvatarBadge extends StatelessWidget {
  final String name;
  const _AvatarBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    String initial = '?';
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      final ch = trimmed.characters.first.toUpperCase();
      if (ch.isNotEmpty) initial = ch;
    }
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Admission number rendered as a soft teal pill with a leading hash to make
/// it scannable without competing with the child's name.
class _AdmissionPill extends StatelessWidget {
  final String admission;
  const _AdmissionPill({required this.admission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentTeal.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.badge_outlined,
            size: 12,
            color: AppColors.accentTeal,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Adm. $admission',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.accentTeal,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
