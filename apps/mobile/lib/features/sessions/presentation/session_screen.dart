import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/firebase_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SessionScreen — Daily.co room loaded in a WebView
//
// Calls the createDailyRoom Cloud Function to get a room URL, then
// loads it in a WebView.  The function requires the DAILY_API_KEY secret
// to be set in Firebase Secret Manager.
// ─────────────────────────────────────────────────────────────────────────────

// Provider that calls createDailyRoom and returns the room URL
final _dailyRoomProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, sessionId) async {
    final fn = ref.read(firebaseFunctionsProvider);
    final callable = fn.httpsCallable('createDailyRoom');
    final result = await callable.call({'bookingId': sessionId});
    final url = result.data['url'] as String?;
    if (url == null || url.isEmpty) throw Exception('Room URL introuvable');
    return url;
  },
);

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  WebViewController? _controller;

  void _initWebView(String url) {
    if (_controller != null) return; // already initialised
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de connexion: ${error.description}')),
          );
        },
      ))
      ..loadRequest(Uri.parse(url));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_dailyRoomProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Session vidéo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Création de la salle...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('$e', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(_dailyRoomProvider(widget.sessionId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (url) {
          _initWebView(url);
          if (_controller == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          return WebViewWidget(controller: _controller!);
        },
      ),
    );
  }
}
