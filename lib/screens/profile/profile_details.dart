import 'package:flutter/material.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/profile/profile_details_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ProfileProvider>().loadFromAuth(auth);
    });
  }

  String _userTypeDisplay(UserType type) {
    switch (type) {
      case UserType.student:
        return 'Student';
      case UserType.guardian:
        return 'Guardian';
      case UserType.teacher:
        return 'Teacher';
      case UserType.admin:
        return 'Admin';
    }
  }

  String? _formatDate(DateTime? d) {
    if (d == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withOpacity(0.05),
              AppColors.secondaryPurple.withOpacity(0.05),
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Consumer2<ProfileProvider, AuthProvider>(
            builder: (context, profileProvider, authProvider, _) {
              if (profileProvider.isLoading && !profileProvider.hasUser) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                  ),
                );
              }

              final user = profileProvider.user ?? authProvider.currentUser;
              if (user == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No profile data',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'My Profile',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Header card with avatar and name
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryBlue.withOpacity(0.85),
                              AppColors.secondaryPurple,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child:
                                  user.photoUrl != null &&
                                      user.photoUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        user.photoUrl!,
                                        fit: BoxFit.cover,
                                        width: 80,
                                        height: 80,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarLetter(user),
                                      ),
                                    )
                                  : _avatarLetter(user),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _userTypeDisplay(user.userType),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Basic info section
                  SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Basic information'),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                      ),
                      child: _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email,
                          ),
                          if (user.phoneNumber != null &&
                              user.phoneNumber!.isNotEmpty)
                            _InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: user.phoneNumber!,
                            ),
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'First name',
                            value: user.firstName ?? '—',
                          ),
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Last name',
                            value: user.lastName ?? '—',
                          ),
                          if (user.displayName != null &&
                              user.displayName != user.fullName)
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Display name',
                              value: user.displayName!,
                            ),
                          _InfoRow(
                            icon: Icons.fingerprint,
                            label: 'User ID',
                            value: user.uid,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Account & dates
                  SliverToBoxAdapter(child: _SectionHeader(title: 'Account')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                      ),
                      child: _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.category_outlined,
                            label: 'Role',
                            value: _userTypeDisplay(user.userType),
                          ),
                          if (_formatDate(user.createdAt) != null)
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Joined',
                              value: _formatDate(user.createdAt)!,
                            ),
                          if (_formatDate(user.updatedAt) != null)
                            _InfoRow(
                              icon: Icons.update,
                              label: 'Last updated',
                              value: _formatDate(user.updatedAt)!,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Additional data (from API: admission_no, session_id, employee_id, etc.)
                  if (user.additionalData != null &&
                      user.additionalData!.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Additional details'),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 16,
                        ),
                        child: _InfoCard(
                          children: _additionalDataRows(user.additionalData!),
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _avatarLetter(UserModel user) {
    final letter =
        (user.firstName?.isNotEmpty == true
                ? user.firstName!.substring(0, 1)
                : user.email.isNotEmpty
                ? user.email.substring(0, 1)
                : 'U')
            .toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _additionalDataRows(Map<String, dynamic> data) {
    final labels = <String, String>{
      'admission_no': 'Admission number',
      'session_id': 'Session ID',
      'employee_id': 'Employee ID',
      'department': 'Department',
      'designation': 'Designation',
      'gender': 'Gender',
      'dob': 'Date of birth',
      'guardian_name': 'Guardian name',
      'username': 'Username',
      'user_id': 'User ID (API)',
      'is_active': 'Active',
      'created_at': 'Created (API)',
      'updated_at': 'Updated (API)',
      'language': 'Language',
      'currency_id': 'Currency ID',
      'lang_id': 'Language ID',
    };
    final icon = Icons.info_outline_rounded;
    return data.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .map((e) {
          final label = labels[e.key] ?? e.key.replaceAll('_', ' ');
          final value = e.value is bool
              ? (e.value as bool ? 'Yes' : 'No')
              : e.value.toString();
          return _InfoRow(icon: icon, label: label, value: value);
        })
        .toList();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.secondaryPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.accentTeal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
