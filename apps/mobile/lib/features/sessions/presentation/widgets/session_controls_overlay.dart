import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/session_model.dart';
import 'session_timer.dart';

class SessionControlsOverlay extends StatefulWidget {
  const SessionControlsOverlay({
    required this.webViewController,
    required this.session,
    required this.onLeave,
    required this.visible,
    this.onSessionEnded,
    super.key,
  });

  final WebViewController webViewController;
  final SessionModel session;
  final VoidCallback onLeave;
  final bool visible;
  final VoidCallback? onSessionEnded;

  @override
  State<SessionControlsOverlay> createState() => _SessionControlsOverlayState();
}

class _SessionControlsOverlayState extends State<SessionControlsOverlay> {
  bool _isVideoOn = true;
  bool _isAudioOn = true;

  Future<void> _invokeDailyMethod(String method, bool value) async {
    try {
      // JS bridge — peut ne pas fonctionner sur tous les appareils
      await widget.webViewController.runJavaScript(
        "window.callObject && window.callObject.callMethod('$method', [$value]);",
      );
    } catch (_) {
      // Best effort only, no crash if JS bridge is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final endTime = widget.session.scheduledAt.add(
      Duration(minutes: widget.session.durationMinutes),
    );

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(185),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SessionTimer(
                    endTime: endTime,
                    onSessionEnded: widget.onSessionEnded,
                  ),
                ),
                IconButton(
                  tooltip: _isAudioOn ? 'Couper micro' : 'Activer micro',
                  icon: Icon(
                    _isAudioOn ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    final next = !_isAudioOn;
                    setState(() => _isAudioOn = next);
                    await _invokeDailyMethod('daily.setLocalAudio', next);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _isVideoOn ? 'Couper caméra' : 'Activer caméra',
                  icon: Icon(
                    _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    final next = !_isVideoOn;
                    setState(() => _isVideoOn = next);
                    await _invokeDailyMethod('daily.setLocalVideo', next);
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: widget.onLeave,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Quitter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}