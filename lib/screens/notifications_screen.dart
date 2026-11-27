import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: NotificationService.markAllRead,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.forMe(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            return AppErrorState(message: '${snapshot.error}');
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none,
              title: 'All quiet',
              message: 'Friend activity and replies will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final read = item['read'] == true;
              return Card(
                color: read ? FlickerColors.surface : FlickerColors.roseWash,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    item['type'] == 'watch_invite'
                        ? Icons.local_fire_department_outlined
                        : Icons.notifications_none,
                    color: FlickerColors.primaryBright,
                  ),
                  title: Text(
                    (item['title'] as String?) ?? 'Update',
                    style: FlickerText.body.copyWith(
                      fontWeight: read ? FontWeight.normal : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text((item['body'] as String?) ?? ''),
                  trailing: read
                      ? null
                      : IconButton(
                          tooltip: 'Mark as read',
                          icon: const Icon(Icons.check),
                          onPressed: () => NotificationService.markRead(
                            item['id'] as String,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
