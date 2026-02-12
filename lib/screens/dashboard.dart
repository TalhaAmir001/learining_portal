import 'package:flutter/material.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/messages/members_provider.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/utils/widgets/dashboard_app_bar.dart';
import 'package:learining_portal/utils/widgets/dashboard_grid_item.dart';
import 'package:learining_portal/utils/widgets/notice_board_box.dart';
import 'package:provider/provider.dart';
import 'messages/chat.dart';
import 'messages/inbox.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final sendNotifications = context.read<SendNotificationsProvider>();
      sendNotifications.setAuthProvider(auth);
      // When WebSocket broadcasts a new notice, refresh the notice board list
      auth.onNewNoticeReceived = (_) {
        sendNotifications.loadNotices();
      };
    });
  }

  /// For teacher, student, guardian: show Support and open chat with Support directly.
  /// For admin: show Messages and open Inbox.
  static List<DashboardItem> _buildDashboardItems(
    BuildContext context,
    UserType? userType,
  ) {
    final isSupportUserType =
        userType == UserType.teacher ||
        userType == UserType.student ||
        userType == UserType.guardian;

    if (isSupportUserType) {
      return [
        DashboardItem(
          icon: Icons.support_agent,
          title: 'Support',
          color: Colors.blue,
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
      ];
    }

    return [
      DashboardItem(
        icon: Icons.message_outlined,
        title: 'Messages',
        color: Colors.blue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InboxScreen()),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.secondaryContainer.withOpacity(0.2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const DashboardAppBar(),
              Expanded(
                child: Consumer2<AuthProvider, SendNotificationsProvider>(
                  builder: (context, authProvider, sendNotifications, _) {
                    final dashboardItems = _buildDashboardItems(
                      context,
                      authProvider.userType,
                    );
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width > 600 ? size.width * 0.1 : 20.0,
                        vertical: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NoticeBoardBox(
                            notices: sendNotifications.notices,
                            isLoading: sendNotifications.isLoading,
                          ),
                          const SizedBox(height: 20),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: size.width > 600 ? 4 : 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                            itemCount: dashboardItems.length,
                            itemBuilder: (context, index) {
                              return DashboardGridItem(
                                item: dashboardItems[index],
                              );
                            },
                          ),
                        ],
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
