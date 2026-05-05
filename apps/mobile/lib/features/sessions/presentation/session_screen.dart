import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SessionScreen
//
// Live tutoring session view powered by Daily.co WebRTC.
//
// Integration steps (not yet wired — requires Daily.co account):
// 1. Add daily_flutter to pubspec.yaml
// 2. Create a Daily room via a Cloud Function (never in client)
// 3. Pass the room URL + participant token to this screen
// 4. Replace the placeholder with CallWidget from daily_flutter
// ─────────────────────────────────────────────────────────────────────────────
class SessionScreen extends ConsumerWidget {
  const SessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Session $sessionId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: const Center(
        child: _SessionPlaceholder(),
      ),
      bottomNavigationBar: const _SessionControls(),
    );
  }
}

class _SessionPlaceholder extends StatelessWidget {
  const _SessionPlaceholder();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          color: AppColors.grey600,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_call_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 12),
            Text(
              'Daily.co WebRTC\nà intégrer',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SessionControls extends StatefulWidget {
  const _SessionControls();
  @override
  State<_SessionControls> createState() => _SessionControlsState();
}

class _SessionControlsState extends State<_SessionControls> {
  bool _micOn    = true;
  bool _cameraOn = true;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon:    _micOn ? Icons.mic : Icons.mic_off,
          label:   _micOn ? 'Micro' : 'Muet',
          active:  _micOn,
          onTap:   () => setState(() => _micOn = !_micOn),
        ),
        _ControlButton(
          icon:    _cameraOn ? Icons.videocam : Icons.videocam_off,
          label:   _cameraOn ? 'Caméra' : 'Caméra off',
          active:  _cameraOn,
          onTap:   () => setState(() => _cameraOn = !_cameraOn),
        ),
        _ControlButton(
          icon:    Icons.call_end,
          label:   'Raccrocher',
          active:  false,
          color:   AppColors.error,
          onTap:   () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label, required this.active, required this.onTap, this.color});
  final IconData icon; final String label; final bool active; final VoidCallback onTap; final Color? color;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: color ?? (active ? AppColors.grey600 : Colors.grey.shade800),
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}
