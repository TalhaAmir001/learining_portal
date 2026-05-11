import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/parent_children/add_child_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Guardian-only screen that lists the children currently linked to this
/// parent and lets them mark one as "active" (the one the rest of the app
/// will scope to). Tap "Add a child" to open [AddChildScreen].
class MyChildrenScreen extends StatefulWidget {
  const MyChildrenScreen({super.key});

  @override
  State<MyChildrenScreen> createState() => _MyChildrenScreenState();
}

class _MyChildrenScreenState extends State<MyChildrenScreen> {
  bool _hasRefreshedOnEnter = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRefreshedOnEnter) {
      _hasRefreshedOnEnter = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AuthProvider>().refreshLinkedChildren();
      });
    }
  }

  Future<void> _onAddChild() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    );
    if (!mounted) return;
    if (added == true) {
      await context.read<AuthProvider>().refreshLinkedChildren();
    }
  }

  Future<void> _onPickActive(ParentChild child) async {
    final auth = context.read<AuthProvider>();
    if (auth.selectedChildId == child.studentId) return;
    final ok = await auth.setSelectedChild(child.studentId);
    if (!mounted) return;
    if (ok) {
      SiChrome.showMessage(context, '${child.fullName} is now active.');
    } else {
      SiChrome.showMessage(context, 'Could not switch active child. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isGuardian = auth.userType == UserType.guardian;
        return SiThemedPageScaffold(
          title: 'My Children',
          subtitle: isGuardian
              ? 'Link your children and pick the active one'
              : 'Available to guardian accounts',
          child: !isGuardian
              ? const _NotGuardianBlock()
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: () => auth.refreshLinkedChildren(),
                  child: _buildBody(context, auth),
                ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AuthProvider auth) {
    if (auth.isLoadingLinkedChildren && auth.linkedChildren.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 96),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (auth.linkedChildren.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (auth.linkedChildrenError != null)
            _ErrorCard(message: auth.linkedChildrenError!),
          const SizedBox(height: 24),
          _EmptyChildrenBlock(onAdd: _onAddChild),
        ],
      );
    }

    final children = auth.linkedChildren;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: children.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == children.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AddChildCta(onTap: _onAddChild),
          );
        }
        final c = children[i];
        return _ChildCard(
          child: c,
          isActive: auth.selectedChildId == c.studentId,
          onTap: () => _onPickActive(c),
        );
      },
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isActive ? 1.6 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primaryBlue.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.secondaryPurple,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            child.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) const _ActiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.admissionNo.isEmpty
                          ? '—'
                          : 'Adm. No: ${child.admissionNo}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (child.classLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        child.classLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isActive
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary.withOpacity(0.45),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Active',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlue,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AddChildCta extends StatelessWidget {
  const _AddChildCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add a child'),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

class _EmptyChildrenBlock extends StatelessWidget {
  const _EmptyChildrenBlock({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SiEmptyState(
          icon: Icons.family_restroom_rounded,
          title: 'No children linked yet',
          message:
              'Ask your school for the 6-character mobile app code printed '
              'on your child\'s profile, then tap "Add a child" to link '
              'them instantly.',
        ),
        const SizedBox(height: 12),
        _AddChildCta(onTap: onAdd),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotGuardianBlock extends StatelessWidget {
  const _NotGuardianBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: SiEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Guardian-only feature',
        message:
            'Sign in with a guardian account to link and switch between '
            'your children.',
      ),
    );
  }
}
