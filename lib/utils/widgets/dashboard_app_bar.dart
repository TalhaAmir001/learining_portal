import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/parent_link/parent_link_models.dart';
import 'package:learining_portal/network/domain/parent_leaving_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/auth/widgets/leaving_notice_dialogs.dart';
import 'package:learining_portal/screens/profile/profile_details.dart';
import 'package:learining_portal/screens/profile/settings.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardAppBar extends StatelessWidget {
  final String schoolName;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSupportPressed;

  const DashboardAppBar({
    super.key,
    required this.schoolName,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.onSupportPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.backgroundLight.withOpacity(0.95)],
        ),
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
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Animated School Logo with Gradient
            _buildSchoolLogo(context),
            const SizedBox(width: 16),

            // School Info with Gradient Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // School Name with Gradient
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.secondaryPurple,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      schoolName,
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color:
                            Colors.white, // This will be overridden by gradient
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Action Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Support icon (outside profile container)
                if (onSupportPressed != null) ...[
                  _buildSupportIconButton(context),
                  const SizedBox(width: 8),
                ],
                // Profile & Logout Section
                _buildProfileSection(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolLogo(BuildContext context) {
    return Hero(
      tag: 'school_logo',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.secondaryPurple.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 48,
            height: 48,
            color: const Color(0xFFD0BDA4),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/icon/app_icon.jpg',
              fit: BoxFit.contain,
              width: 43,
              height: 43,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportIconButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSupportPressed,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.accentTeal.withOpacity(0.2),
        highlightColor: AppColors.accentTeal.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentTeal.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  size: 22,
                  color: AppColors.accentTeal,
                ),
              ),
              // 'Live' label at top right corner
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.backgroundLight, Colors.white],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  onProfilePressed ??
                  () {
                    _showProfileMenu(context, authProvider);
                  },
              borderRadius: BorderRadius.circular(30),
              splashColor: AppColors.primaryBlue.withOpacity(0.1),
              highlightColor: AppColors.secondaryPurple.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Avatar with Gradient
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.secondaryPurple,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          authProvider.userName
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              authProvider.userEmail
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Logout Icon with Gradient
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfileMenu(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // For guardians, pre-resolve "is your subscription past its leaving
    // date?" before opening the sheet — that way the End Subscription tile
    // renders in the right colour on first paint. SharedPreferences is
    // local so this is a sub-frame round trip.
    bool isSubscriptionEnded = false;
    if (authProvider.userType == UserType.guardian) {
      final pid = authProvider.guardianParentId;
      if (pid != null) {
        isSubscriptionEnded =
            await ParentLeavingRepository.isSubscriptionEnded(appParentId: pid);
      }
    }
    if (!context.mounted) return;

    // Capture the dashboard context (alive for the whole session) — used
    // by tiles that need to open additional routes *after* this bottom
    // sheet is popped (e.g. the End Subscription dialog flow). The sheet
    // builder's own context becomes unmounted the moment Navigator.pop()
    // runs, which would otherwise kill any follow-up showDialog calls.
    final hostContext = context;

    showModalBottomSheet(
      context: context,
      // Without isScrollControlled the sheet caps at ~9/16 of the screen,
      // which on shorter phones (or with larger system font scales) is
      // smaller than the guardian's full menu (header + 4 tiles + dividers)
      // and causes a RenderFlex overflow. Letting it grow + capping at 85 %
      // of screen height lets the inner scroll view kick in when needed.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildProfileMenu(
        sheetContext,
        authProvider,
        hostContext: hostContext,
        isSubscriptionEnded: isSubscriptionEnded,
      ),
    );
  }

  Widget _buildProfileMenu(
    BuildContext context,
    AuthProvider authProvider, {
    required BuildContext hostContext,
    bool isSubscriptionEnded = false,
  }) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.backgroundLight],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Everything below the handle scrolls if the device is too
              // short to display the full menu — guarantees we never bust
              // the sheet's max-height constraint regardless of the user's
              // type, font scale, or display size.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  authProvider.userName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      authProvider.userEmail
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    authProvider.userName ?? 'User',
                                    style: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    authProvider.userEmail ?? '',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, indent: 24, endIndent: 24),

                      _buildMenuItem(
                        icon: Icons.person_outline_rounded,
                        title: 'My Profile',
                        color: AppColors.primaryBlue,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileDetailsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        color: AppColors.secondaryPurple,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.delete_outline_rounded,
                        title: 'Request delete account',
                        color: AppColors.accentTeal,
                        onTap: () {
                          Navigator.pop(context);
                          _openAccountDeletionUrl(context);
                        },
                      ),

                      // End Subscription — guardian-only. Sits directly
                      // above Logout so it shares the same "leaving the
                      // portal" mental model. The tile turns grey on/after
                      // the parent's previously-submitted leaving date.
                      if (authProvider.userType == UserType.guardian &&
                          authProvider.guardianParentId != null)
                        _buildMenuItem(
                          icon: isSubscriptionEnded
                              ? Icons.event_available_rounded
                              : Icons.event_busy_rounded,
                          title: 'End Subscription',
                          color: isSubscriptionEnded
                              ? (Colors.grey[600] ?? Colors.grey)
                              : Colors.red[600] ?? Colors.red,
                          onTap: () {
                            final parentId = authProvider.guardianParentId!;
                            // Capture *now* so the snapshot doesn't drift if
                            // the parent switches active child between tap
                            // and dialog open.
                            final activeChild = authProvider.selectedChild;
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!hostContext.mounted) return;
                              _openEndSubscriptionFlow(
                                hostContext,
                                parentId,
                                activeChild: activeChild,
                              );
                            });
                          },
                        ),

                      const Divider(height: 1, indent: 24, endIndent: 24),

                      _buildMenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        color: Colors.red,
                        showBorder: false,
                        onTap: () {
                          Navigator.pop(context);
                          _showLogoutConfirmation(context);
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool showBorder = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          onTap: onTap,
        ),
        if (showBorder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              height: 1,
              color: AppColors.textSecondary.withOpacity(0.1),
            ),
          ),
      ],
    );
  }

  /// Drives the two-step Leaving Notice dialog flow and shows the confirmation
  /// snackbar on success. Called from the End Subscription tile in the
  /// profile bottom sheet — by the time this runs, the sheet itself has
  /// already been popped, so the dialogs render against the dashboard.
  Future<void> _openEndSubscriptionFlow(
    BuildContext context,
    int appParentId, {
    ParentChild? activeChild,
  }) async {
    await showEndSubscriptionFlow(
      context: context,
      appParentId: appParentId,
      activeChild: activeChild,
    );
  }

  Future<void> _openAccountDeletionUrl(BuildContext context) async {
    final uri = Uri.parse(accountDeletionRequestUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the link. Please try again later.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the link. Please try again later.'),
          ),
        );
      }
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
