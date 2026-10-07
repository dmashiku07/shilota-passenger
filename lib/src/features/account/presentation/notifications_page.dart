import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const routePath = '/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<ApiListResponse<NotificationItem>>(
        future: repository.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final data = snapshot.data;
          final items = data?.items ?? const <NotificationItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFCE7E1),
                  child: Icon(
                    item.title.toLowerCase().contains('cancel')
                        ? Icons.cancel_outlined
                        : Icons.notifications_active_outlined,
                    color: const Color(0xFFF04E29),
                  ),
                ),
                title: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.message),
                ),
                trailing: Text(
                  _formatTimestamp(item.notifiedAt),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF7F756F)),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  String _formatTimestamp(String value) {
    final milliseconds = int.tryParse(value);
    if (milliseconds == null) {
      return value;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return DateFormat('dd MMM, HH:mm').format(date);
  }
}
