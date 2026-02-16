import 'package:flutter/material.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/messages/members_provider.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/screens/messages/chat.dart';
import 'package:learining_portal/screens/messages/inbox.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/widgets/dashboard_app_bar.dart';
import 'package:learining_portal/utils/widgets/dashboard_grid_item.dart';
import 'package:learining_portal/screens/notices/notice_board.dart';
import 'package:learining_portal/utils/widgets/notice_board_box.dart';
import 'package:learining_portal/utils/widgets/welcome_section.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      final auth = context.read<AuthProvider>();
      final sendNotifications = context.read<SendNotificationsProvider>();
      sendNotifications.setAuthProvider(auth);
      auth.onNewNoticeReceived = (_) {
        sendNotifications.loadNotices();
      };
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<DashboardItem> _buildDashboardItems(
    BuildContext context,
    UserType? userType,
  ) {
    final isSupportUserType =
        userType == UserType.teacher ||
        userType == UserType.student ||
        userType == UserType.guardian;

    final List<DashboardItem> items = [];

    // Always show Dashboard Home

    if (isSupportUserType) {
      items.add(
        DashboardItem(
          icon: Icons.support_agent_rounded,
          title: 'Support Chat',
          color: AppColors.accentTeal,
          gradient: const LinearGradient(
            colors: [AppColors.accentTeal, AppColors.secondaryPurple],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatScreenWrapper(otherUser: MembersProvider.supportUser),
              ),
            );
          },
        ),
      );
    } else {
      items.add(
        DashboardItem(
          icon: Icons.message_rounded,
          title: 'Messages',
          color: AppColors.accentTeal,
          gradient: const LinearGradient(
            colors: [AppColors.accentTeal, AppColors.primaryBlue],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InboxScreen()),
            );
          },
        ),
      );
    }

    // Add more dashboard items based on user type
    if (userType == UserType.admin) {
      items.addAll([
        DashboardItem(
          icon: Icons.people_rounded,
          title: 'Users',
          color: AppColors.secondaryPurple,
          gradient: const LinearGradient(
            colors: [AppColors.secondaryPurple, AppColors.primaryBlue],
          ),
          onTap: () {
            // Navigate to user management
          },
        ),
        DashboardItem(
          icon: Icons.analytics_rounded,
          title: 'Analytics',
          color: AppColors.primaryBlue,
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.accentTeal],
          ),
          onTap: () {
            // Navigate to analytics
          },
        ),
      ]);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final isSupportUserType =
                      authProvider.userType == UserType.teacher ||
                      authProvider.userType == UserType.student ||
                      authProvider.userType == UserType.guardian;
                  return DashboardAppBar(
                    schoolName: "GCSE With Rosi",
                    onSupportPressed: isSupportUserType
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreenWrapper(
                                  otherUser: MembersProvider.supportUser,
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
              Expanded(
                child: Consumer2<AuthProvider, SendNotificationsProvider>(
                  builder: (context, authProvider, sendNotifications, _) {
                    final dashboardItems = _buildDashboardItems(
                      context,
                      authProvider.userType,
                    );

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? size.width * 0.08 : 16.0,
                        vertical: 24.0,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              WelcomeSection(authProvider: authProvider),
                              const SizedBox(height: 24),

                              // Notice Board
                              NoticeBoardBox(
                                notices: sendNotifications.notices,
                                isLoading: sendNotifications.isLoading,
                                onViewAll: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NoticeBoardScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),

                              // Quick Actions Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Quick Actions',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentTeal.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${dashboardItems.length} options',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.accentTeal,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Dashboard Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isTablet ? 4 : 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.0,
                                    ),
                                itemCount: dashboardItems.length,
                                itemBuilder: (context, index) {
                                  return DashboardGridItem(
                                    item: dashboardItems[index],
                                    index: index,
                                  );
                                },
                              ),

                              // Footer
                              const SizedBox(height: 24),
                              Center(
                                child: Text(
                                  '© 2026 GCSE with Rosi',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary
                                            .withOpacity(0.5),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
