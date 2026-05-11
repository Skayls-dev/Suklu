import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/session_repository.dart';
import '../domain/session_model.dart';
import 'session_providers.dart';
import 'widgets/pre_session_waiting_screen.dart';
import 'widgets/session_controls_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SessionScreen
//
// Point d'entrée vidéo basé sur bookingId (et non sessionId). L'écran :
// 1) retrouve la session liée au booking,
// 2) crée la salle côté tuteur si nécessaire,
// 3) affiche le WebView Daily.co quand roomUrl est disponible.
//
// IMPORTANT Android:
// Vérifier apps/mobile/android/app/src/main/AndroidManifest.xml et ajouter:
// <uses-permission android:name="android.permission.CAMERA"/>
// <uses-permission android:name="android.permission.RECORD_AUDIO"/>
// <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
//
// IMPORTANT WebView:
// Voir la doc webview_flutter pour la config média (autoplay/permissions) selon plateforme.
// ─────────────────────────────────────────────────────────────────────────────
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  WebViewController? _controller;
  String? _loadedRoomUrl;
  bool _overlayVisible = true;
  bool _pageLoaded = false;
  bool _sessionEndHandled = false;
  String? _createdSessionId;
  String? _openedWebRoomUrl;
  bool _joinUrlRequested = false;

  bool get _isTutorSide {
    final role = ref.read(authStateNotifierProvider).value?.role;
    return role == UserRole.tutor ||
        role == UserRole.academicStaff ||
        role == UserRole.superAdmin;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    try {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } finally {
      super.dispose();
    }
  }

  Future<void> _createRoom() async {
    final created = await ref.read(createRoomProvider(widget.bookingId).notifier).create();
    if (created != null) {
      _joinUrlRequested = true;
      _createdSessionId = created.sessionId;
      ref.invalidate(sessionByBookingIdProvider(widget.bookingId));
      ref.invalidate(sessionStreamProvider(created.sessionId));
      if (mounted) setState(() {});
    }
  }

  Future<void> _initWebView(String roomUrl) async {
    if (_loadedRoomUrl == roomUrl && _controller != null) return;
    _pageLoaded = false;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _pageLoaded = true);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur de connexion vidéo : ${error.description}. Vérifiez votre connexion internet.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(roomUrl));

    _loadedRoomUrl = roomUrl;
    if (mounted) setState(() {});
  }

  Future<void> _openRoomOnWeb(String roomUrl) async {
    if (_openedWebRoomUrl == roomUrl) return;
    _openedWebRoomUrl = roomUrl;

    final uri = Uri.tryParse(roomUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL de salle invalide.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir la salle vidéo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _leaveSession() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la session ?'),
        content: const Text('Vous pouvez revenir tant que la session est active.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Rester'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      context.pop();
    }
  }

  Future<void> _onSessionEnded(SessionModel session) async {
    if (_sessionEndHandled) return;
    _sessionEndHandled = true;

    if (_isTutorSide) {
      try {
        await ref.read(sessionRepositoryProvider).updateStatus(session.id, SessionStatus.completed);
      } catch (_) {
        // Non bloquant: la session peut déjà être marquée completed côté serveur.
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session terminée')),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) context.pop();
  }

  String _friendlyCreateError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('failed-precondition') || msg.contains('412')) {
      return 'La réservation doit être confirmée avant de démarrer la session.';
    }
    if (msg.contains('permission-denied') || msg.contains('403')) {
      return 'Vous n\'êtes pas autorisé à créer cette salle.';
    }
    if (msg.contains('not-found') || msg.contains('404')) {
      return 'Réservation introuvable.';
    }
    return 'Impossible de créer la salle vidéo : $error';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<({String roomUrl, String sessionId})?>>(
      createRoomProvider(widget.bookingId),
      (previous, next) {
        if (next.hasError && !next.isLoading && previous?.isLoading == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyCreateError(next.error!)),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
    );

    final createdState = ref.watch(createRoomProvider(widget.bookingId));
    final createdData = createdState.valueOrNull;

    final sessionByBookingAsync = ref.watch(sessionByBookingIdProvider(widget.bookingId));

    return sessionByBookingAsync.when(
      loading: () => _scaffold(
        title: 'Session en cours',
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _scaffold(
        title: 'Session en cours',
        child: PreSessionWaitingScreen(
          isTutorSide: _isTutorSide,
          onBack: () => context.pop(),
          createRoomState: createdState,
          onCreateRoom: _isTutorSide ? _createRoom : null,
          onRefresh: () => ref.invalidate(sessionByBookingIdProvider(widget.bookingId)),
        ),
      ),
      data: (sessionByBooking) {
        final activeSessionId = sessionByBooking?.id ?? createdData?.sessionId ?? _createdSessionId;

        if (activeSessionId == null) {
          return _scaffold(
            title: 'Session en cours',
            child: PreSessionWaitingScreen(
              isTutorSide: _isTutorSide,
              onBack: () => context.pop(),
              createRoomState: createdState,
              onCreateRoom: _isTutorSide ? _createRoom : null,
              onRefresh: () => ref.invalidate(sessionByBookingIdProvider(widget.bookingId)),
            ),
          );
        }

        final sessionAsync = ref.watch(sessionStreamProvider(activeSessionId));

        return sessionAsync.when(
          loading: () => _scaffold(
            title: 'Session en cours',
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _scaffold(
            title: 'Session en cours',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Erreur de session : $error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(sessionStreamProvider(activeSessionId)),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (session) {
            if (session == null) {
              final createdRoomUrl = createdData?.roomUrl;
              if ((createdRoomUrl ?? '').isNotEmpty) {
                if (kIsWeb) {
                  final roomUrl = createdRoomUrl!;
                  unawaited(_openRoomOnWeb(roomUrl));

                  return _scaffold(
                    title: 'Session en cours',
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text(
                              'Ouverture de la salle vidéo...',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _openRoomOnWeb(roomUrl),
                              child: const Text('Ouvrir manuellement'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                unawaited(_initWebView(createdRoomUrl!));
                if (_controller != null) {
                  return Scaffold(
                    backgroundColor: Colors.black,
                    appBar: _overlayVisible
                        ? AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            title: const Text('Session en cours'),
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _leaveSession,
                              ),
                            ],
                            bottom: !_pageLoaded
                                ? const PreferredSize(
                                    preferredSize: Size.fromHeight(2),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  )
                                : null,
                          )
                        : null,
                    body: Stack(
                      children: [
                        WebViewWidget(controller: _controller!),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _overlayVisible = !_overlayVisible),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }

              return _scaffold(
                title: 'Session en cours',
                child: PreSessionWaitingScreen(
                  isTutorSide: _isTutorSide,
                  onBack: () => context.pop(),
                  createRoomState: createdState,
                  onCreateRoom: _isTutorSide ? _createRoom : null,
                  onRefresh: () => ref.invalidate(sessionStreamProvider(activeSessionId)),
                ),
              );
            }

            if ((session.roomUrl ?? '').isEmpty) {
              return _scaffold(
                title: 'Session en cours',
                child: PreSessionWaitingScreen(
                  isTutorSide: _isTutorSide,
                  session: session,
                  onBack: () => context.pop(),
                  createRoomState: createdState,
                  onCreateRoom: _isTutorSide ? _createRoom : null,
                  onRefresh: () {
                    ref.invalidate(sessionStreamProvider(activeSessionId));
                    ref.invalidate(sessionByBookingIdProvider(widget.bookingId));
                  },
                ),
              );
            }

            if (!session.isAccessible && !_isTutorSide) {
              return _scaffold(
                title: 'Session en cours',
                child: PreSessionWaitingScreen(
                  isTutorSide: _isTutorSide,
                  session: session,
                  onBack: () => context.pop(),
                  createRoomState: createdState,
                  onCreateRoom: _isTutorSide ? _createRoom : null,
                  onRefresh: () => ref.invalidate(sessionStreamProvider(activeSessionId)),
                ),
              );
            }

            if (!_joinUrlRequested && createdData == null) {
              _joinUrlRequested = true;
              unawaited(_createRoom());
            }

            final effectiveRoomUrl = createdData?.roomUrl ?? session.roomUrl;
            if ((effectiveRoomUrl ?? '').isEmpty) {
              return _scaffold(
                title: 'Session en cours',
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (kIsWeb) {
              final roomUrl = effectiveRoomUrl!;
              unawaited(_openRoomOnWeb(roomUrl));

              return _scaffold(
                title: 'Session en cours',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Ouverture de la salle vidéo...',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _openRoomOnWeb(roomUrl),
                          child: const Text('Ouvrir manuellement'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            unawaited(_initWebView(effectiveRoomUrl!));

            if (_controller == null) {
              return _scaffold(
                title: 'Session en cours',
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: _overlayVisible
                  ? AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      title: const Text('Session en cours'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _leaveSession,
                        ),
                      ],
                      bottom: !_pageLoaded
                          ? const PreferredSize(
                              preferredSize: Size.fromHeight(2),
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : null,
                    )
                  : null,
              body: Stack(
                children: [
                  WebViewWidget(controller: _controller!),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _overlayVisible = !_overlayVisible),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  SessionControlsOverlay(
                    webViewController: _controller!,
                    session: session,
                    visible: _overlayVisible,
                    onLeave: _leaveSession,
                    onSessionEnded: () => _onSessionEnded(session),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Scaffold _scaffold({required String title, required Widget child}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: child,
    );
  }
}
