import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';

class FcmTokenService {
  FcmTokenService({
    required FirebaseFirestore firestore,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  String? _lastSavedToken;

  Future<void> initAndSave(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied by user');
        return;
      }

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('FCM permission not determined');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM token is null or empty');
        return;
      }

      final platform = _platformLabel();
      if (platform == null) {
        debugPrint('FCM token skipped for unsupported platform');
        return;
      }

      await _saveToken(uid, token, platform: platform);

      _messaging.onTokenRefresh.listen((newToken) async {
        await _saveToken(
          uid,
          newToken,
          platform: platform,
          previousToken: _lastSavedToken,
        );
      });
    } catch (e) {
      // FCM setup should never break auth/navigation flows.
      debugPrint('FCM initAndSave failed: $e');
    }
  }

  Future<void> _saveToken(
    String uid,
    String token, {
    required String platform,
    String? previousToken,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final snap = await userRef.get();

    final currentData = snap.data() ?? <String, dynamic>{};
    final tokens = Map<String, dynamic>.from(
      currentData['fcmTokens'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    tokens[token] = platform;

    if (previousToken != null && previousToken != token) {
      tokens.remove(previousToken);
    }

    await userRef.set({'fcmTokens': tokens}, SetOptions(merge: true));
    _lastSavedToken = token;
  }

  String? _platformLabel() {
    if (kIsWeb) return null;
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return null;
  }
}

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService(firestore: ref.watch(firestoreProvider));
});
