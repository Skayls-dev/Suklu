import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class SessionTimer extends StatefulWidget {
  const SessionTimer({
    required this.endTime,
    this.onSessionEnded,
    super.key,
  });

  final DateTime endTime;
  final VoidCallback? onSessionEnded;

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  late Duration _remaining;
  Timer? _timer;
  bool _endedCallbackSent = false;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _computeRemaining());

      if (_remaining == Duration.zero && !_endedCallbackSent) {
        _endedCallbackSent = true;
        widget.onSessionEnded?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _computeRemaining() {
    final diff = widget.endTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final underFiveMinutes = _remaining > Duration.zero && _remaining < const Duration(minutes: 5);
    final underOneMinute = _remaining > Duration.zero && _remaining < const Duration(minutes: 1);
    final isEnded = _remaining == Duration.zero;

    final color = isEnded
        ? AppColors.error
        : underOneMinute
            ? AppColors.error
            : underFiveMinutes
                ? AppColors.warning
                : Colors.white;

    final label = isEnded
        ? 'Session terminée'
        : underOneMinute
            ? 'Session se termine bientôt'
            : 'Temps restant';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _format(_remaining),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}