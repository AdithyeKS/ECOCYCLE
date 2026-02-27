import 'package:flutter/material.dart';
import 'package:ecocycle/models/notification_item.dart';
import 'package:ecocycle/services/notification_service.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationItem> notifications = [];
  bool isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        // Fetch user role if not already fetched
        if (_userRole == null) {
          final profile = await AppSupabase.client
              .from('profiles')
              .select('user_role')
              .eq('id', userId)
              .maybeSingle();
          _userRole = profile?['user_role'] as String? ?? 'user';
        }

        final fetchedNotifications = await _notificationService
            .fetchNotifications(userId, userRole: _userRole);
        setState(() {
          notifications = fetchedNotifications;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);
      setState(() {
        final index = notifications.indexOf(notification);
        notifications[index] = NotificationItem(
          id: notification.id,
          userId: notification.userId,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          isRead: true,
          createdAt: notification.createdAt,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        await _notificationService.markAllAsRead(userId);
        await _loadNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications marked as read')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'email_notification':
        return Colors.orange;
      case 'status_update':
        return Colors.blue;
      case 'points_earned':
        return Colors.green;
      case 'delivery_pickup':
        return Colors.purple;
      case 'otp_message':
        return Colors.deepOrange;
      case 'assignment_new':
        return Colors.blue;
      case 'assignment_pending':
        return Colors.amber;
      case 'collection_request':
        return Colors.teal;
      case 'volunteer_revoked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'email_notification':
        return Icons.mail_outline;
      case 'status_update':
        return Icons.info_outline;
      case 'points_earned':
        return Icons.star_outline;
      case 'delivery_pickup':
        return Icons.local_shipping;
      case 'otp_message':
        return Icons.lock_outline;
      case 'assignment_new':
        return Icons.assignment_turned_in;
      case 'assignment_pending':
        return Icons.pending_actions;
      case 'collection_request':
        return Icons.inventory_2_outlined;
      case 'volunteer_revoked':
        return Icons.person_remove;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0a0e27) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color:
                              isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see updates and messages here',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final notificationColor =
                          _getNotificationColor(notification.type);
                      final notificationIcon =
                          _getNotificationIcon(notification.type);

                      return Card(
                        elevation: isDarkMode ? 8 : 2,
                        color: notification.isRead
                            ? (isDarkMode
                                ? const Color(0xFF1a1f3a)
                                : Colors.white)
                            : (isDarkMode
                                ? const Color(0xFF262b49)
                                : Colors.blue.shade50),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: notification.isRead
                              ? BorderSide.none
                              : BorderSide(
                                  color:
                                      notificationColor.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                        ),
                        child: InkWell(
                          onTap: () => _markAsRead(notification),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: notificationColor.withValues(
                                        alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    notificationIcon,
                                    color: notificationColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notification.title,
                                              style: TextStyle(
                                                fontWeight: notification.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.bold,
                                                fontSize: 16,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (!notification.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: notificationColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        notification.message,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('MMM d, yyyy • h:mm a')
                                            .format(notification.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode
                                              ? Colors.grey[500]
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ],
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
    );
  }
}
