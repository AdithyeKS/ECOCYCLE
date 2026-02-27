import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/models/notification_item.dart';

class NotificationService {
  /// Fetch all notifications for a user, sorted by newest first
  /// For regular users, only fetch important notifications
  /// For volunteers/admins, fetch all notifications
  Future<List<NotificationItem>> fetchNotifications(String userId,
      {String? userRole}) async {
    try {
      var query = AppSupabase.client
          .from('notifications')
          .select()
          .eq('user_id', userId);

      // Filter by importance for regular users only
      if (userRole == null || userRole == 'user') {
        query = query.eq('importance', 'high');
      }

      final response = await query.order('created_at', ascending: false);
      final now = DateTime.now().toUtc();

      // Background cleanup: Delete expired OTPs from database
      _cleanupExpiredOTPs(userId);

      return (response as List)
          .map((json) => NotificationItem.fromJson(json))
          .where((notification) {
        if (notification.type == 'otp_message') {
          // Filter out OTPs older than 10 minutes (using UTC for consistency)
          final createdAtUtc = notification.createdAt.toUtc();
          final difference = now.difference(createdAtUtc);
          return difference.inMinutes < 10;
        }
        return true;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Secretly cleanup expired OTP notifications from the database
  Future<void> _cleanupExpiredOTPs(String userId) async {
    try {
      final tenMinutesAgo =
          DateTime.now().toUtc().subtract(const Duration(minutes: 10));

      await AppSupabase.client
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .eq('type', 'otp_message')
          .lt('created_at', tenMinutesAgo.toIso8601String());
    } catch (e) {
      // Background task, fail silently
    }
  }

  /// Get count of unread notifications
  /// For regular users, only count important notifications
  Future<int> getUnreadCount(String userId, {String? userRole}) async {
    try {
      var query = AppSupabase.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      // Filter by importance for regular users only
      if (userRole == null || userRole == 'user') {
        query = query.eq('importance', 'high');
      }

      final response = await query;

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await AppSupabase.client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await AppSupabase.client
          .from('notifications')
          .update({'is_read': true}).eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Create a delivery pickup notification (HIGH importance)
  Future<void> createDeliveryPickupNotification(
      String userId, String itemName, DateTime pickupDate) async {
    try {
      await AppSupabase.client.from('notifications').insert({
        'user_id': userId,
        'title': 'Pickup Scheduled',
        'message':
            'Your $itemName is scheduled for pickup on ${pickupDate.day}/${pickupDate.month}/${pickupDate.year}',
        'type': 'delivery_pickup',
        'importance': 'high',
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Failed to create delivery pickup notification: $e');
    }
  }

  /// Create an OTP notification (HIGH importance)
  Future<void> createOTPNotification(
      String userId, String otp, String purpose) async {
    try {
      await AppSupabase.client.from('notifications').insert({
        'user_id': userId,
        'title': 'OTP for $purpose',
        'message': 'Your OTP is: $otp. Valid for 10 minutes.',
        'type': 'otp_message',
        'importance': 'high',
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Failed to create OTP notification: $e');
    }
  }

  /// Create an assignment notification for volunteers
  Future<void> createAssignmentNotification(
      String userId, String assignmentType, String details) async {
    try {
      final type =
          assignmentType == 'pending' ? 'assignment_pending' : 'assignment_new';
      await AppSupabase.client.from('notifications').insert({
        'user_id': userId,
        'title': assignmentType == 'pending'
            ? 'Assignment Pending'
            : 'New Assignment',
        'message': details,
        'type': type,
        'importance': 'high',
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Failed to create assignment notification: $e');
    }
  }

  /// Create a collection request notification (HIGH importance)
  Future<void> createCollectionNotification(
      String userId, String collectionDetails) async {
    try {
      await AppSupabase.client.from('notifications').insert({
        'user_id': userId,
        'title': 'Collection Request',
        'message': collectionDetails,
        'type': 'collection_request',
        'importance': 'high',
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Failed to create collection notification: $e');
    }
  }

  /// Create a volunteer revocation notification (HIGH importance)
  Future<void> createRevocationNotification(
      String userId, String reason) async {
    try {
      await AppSupabase.client.from('notifications').insert({
        'user_id': userId,
        'title': 'Volunteer Status Revoked',
        'message': 'Your volunteer status has been revoked. Reason: $reason',
        'type': 'volunteer_revoked',
        'importance': 'high',
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Failed to create revocation notification: $e');
    }
  }
}
