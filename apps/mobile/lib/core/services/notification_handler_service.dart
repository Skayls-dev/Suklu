import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationHandlerService {
  NotificationHandlerService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  bool _initialized = false;

  Future<void> init(GoRouter router) async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen((message) {
      _handleNotification(message, router: router);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotification(message, router: router);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotification(initialMessage, router: router);
    }
  }

  void _handleNotification(RemoteMessage message, {required GoRouter router}) {
    final data = message.data;
    final type = data['type'];

    if (type == null) return;

    switch (type) {
      case 'booking_confirmed':
        final bookingId = data['bookingId'];
        if (bookingId != null && bookingId.toString().isNotEmpty) {
          unawaited(_safePush(router, '/student/booking/$bookingId'));
        }
        break;
      case 'session_reminder':
        final bookingId = data['bookingId'];
        if (bookingId != null && bookingId.toString().isNotEmpty) {
          unawaited(_safePush(router, '/student/session/$bookingId'));
        }
        break;
      case 'session_completed':
        unawaited(_safePush(router, '/student/progress'));
        break;
      case 'tutor_message':
        unawaited(_safePush(router, '/student/ai-tutor'));
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  Future<void> _safePush(GoRouter router, String route) async {
    try {
      router.push(route);
    } catch (e) {
      debugPrint('Notification navigation failed for $route: $e');
    }
  }
}

final notificationHandlerServiceProvider = Provider<NotificationHandlerService>((_) {
  return NotificationHandlerService();
});
