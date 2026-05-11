import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Run `flutterfire configure` from apps/mobile to regenerate firebase_options.dart
// with your real project credentials.
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initFirestoreOffline();

  runApp(
    // ProviderScope is the Riverpod root — must wrap the entire widget tree
    const ProviderScope(child: SukluApp()),
  );
}

Future<void> initFirestoreOffline() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Unlimited local cache is intentional for low-connectivity contexts.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}
