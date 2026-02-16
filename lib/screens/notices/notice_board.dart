import 'package:flutter/material.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/widgets/notice/notice_app_bar.dart';
import 'package:learining_portal/utils/widgets/notice/notice_list_item.dart';
import 'package:provider/provider.dart';

/// Full-screen list of all notices. Opened from "View All" or "+ more" on the dashboard.
class NoticeBoardScreen extends StatelessWidget {
  const NoticeBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryPurple,
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.25, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeAppBar(title: 'Notice Board'),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _buildBody(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<SendNotificationsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.notices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading notices...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.errorMessage != null && provider.notices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => provider.loadNotices(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.notices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No notices at the moment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for updates',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadNotices(),
          color: AppColors.primaryBlue,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: provider.notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notice = provider.notices[index];
              return NoticeListItem(
                notice: notice,
                onReturnFromDetail: () => provider.loadNotices(),
              );
            },
          ),
        );
      },
    );
  }
}
