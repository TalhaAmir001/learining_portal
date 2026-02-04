import 'package:flutter/material.dart';
import 'package:learining_portal/utils/widgets/dashboard_app_bar.dart';
import 'package:learining_portal/utils/widgets/dashboard_grid_item.dart';
import 'messages/inbox.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    // Dashboard items with icons and text
    final List<DashboardItem> dashboardItems = [
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
      // DashboardItem(
      //   icon: Icons.school_outlined,
      //   title: 'Teachers',
      //   color: Colors.orange,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Teachers management coming soon!')),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.family_restroom_outlined,
      //   title: 'Guardians',
      //   color: Colors.green,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Guardians management coming soon!')),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.book_outlined,
      //   title: 'Courses',
      //   color: Colors.purple,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Courses management coming soon!')),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.assessment_outlined,
      //   title: 'Reports',
      //   color: Colors.red,
      //   onTap: () {
      //     ScaffoldMessenger.of(
      //       context,
      //     ).showSnackBar(const SnackBar(content: Text('Reports coming soon!')));
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.settings_ethernet_outlined,
      //   title: 'WebSocket Status',
      //   color: Colors.teal,
      //   onTap: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => const WebSocketStatusScreen(),
      //       ),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.settings_outlined,
      //   title: 'Settings',
      //   color: Colors.grey,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Settings coming soon!')),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.notifications_outlined,
      //   title: 'Notifications',
      //   color: Colors.amber,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Notifications coming soon!')),
      //     );
      //   },
      // ),
      // DashboardItem(
      //   icon: Icons.analytics_outlined,
      //   title: 'Analytics',
      //   color: Colors.teal,
      //   onTap: () {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Analytics coming soon!')),
      //     );
      //   },
      // ),
    ];

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
              // App Bar
              const DashboardAppBar(),

              // Dashboard Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? size.width * 0.1 : 20.0,
                    vertical: 24.0,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size.width > 600 ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: dashboardItems.length,
                    itemBuilder: (context, index) {
                      return DashboardGridItem(item: dashboardItems[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
