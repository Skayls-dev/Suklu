import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/session_model.dart';

class PreSessionWaitingScreen extends ConsumerStatefulWidget {
  const PreSessionWaitingScreen({
    required this.isTutorSide,
    required this.onBack,
    this.session,
    this.onCreateRoom,
    this.createRoomState,
    this.onRefresh,
    super.key,
  });

  final bool isTutorSide;
  final SessionModel? session;
  final VoidCallback onBack;
  final Future<void> Function()? onCreateRoom;
  final AsyncValue<({String roomUrl, String sessionId})?>? createRoomState;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<PreSessionWaitingScreen> createState() => _PreSessionWaitingScreenState();
}

class _PreSessionWaitingScreenState extends ConsumerState<PreSessionWaitingScreen> {
  Timer? _pollTimer;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      widget.onRefresh?.call();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(date);
  }

  String? _friendlyCreateError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission-denied') || message.contains('403')) {
      return 'Vous n\'êtes pas autorisé à créer cette salle.';
    }
    if (message.contains('failed-precondition') || message.contains('412')) {
      return 'La réservation doit être confirmée avant de démarrer.';
    }
    if (message.contains('not-found') || message.contains('404')) {
      return 'Réservation introuvable.';
    }
    return 'Impossible de créer la salle vidéo pour le moment.';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final waitTooLong = DateTime.now().difference(_openedAt) > const Duration(minutes: 2);
    final isExpired = session != null &&
        DateTime.now().isAfter(
          session.scheduledAt.add(Duration(minutes: session.durationMinutes + 30)),
        );

    if (isExpired) {
      return _MessageCard(
        icon: Icons.timer_off_outlined,
        title: 'Cette session est terminée.',
        subtitle: 'La fenêtre d\'accès est expirée.',
        primaryLabel: 'Retour',
        onPrimary: widget.onBack,
      );
    }

    if (!widget.isTutorSide) {
      final subtitle = session == null
          ? 'La salle sera disponible 5 minutes avant le début.'
          : 'Votre session commence le ${_formatDate(session.scheduledAt)}\nDurée : ${session.durationMinutes} minutes\n\nLa salle sera disponible 5 minutes avant le début.';

      return _MessageCard(
        icon: Icons.schedule,
        title: 'Session en préparation',
        subtitle: '$subtitle${waitTooLong ? '\n\nLa salle n\'est toujours pas disponible. Contactez votre tuteur.' : ''}',
        primaryLabel: 'Retour au tableau de bord',
        onPrimary: widget.onBack,
      );
    }

    final createState = widget.createRoomState;
    final isLoading = createState?.isLoading ?? false;
    final err = createState?.error;

    return _MessageCard(
      icon: Icons.video_call_outlined,
      title: 'La salle n\'est pas encore créée.',
      subtitle: session == null
          ? 'Créez la salle vidéo pour permettre aux participants de rejoindre la session.'
          : 'Session prévue le ${_formatDate(session.scheduledAt)}',
      errorText: err == null ? null : _friendlyCreateError(err),
      primaryLabel: isLoading ? 'Création...' : 'Créer la salle vidéo',
      onPrimary: isLoading
          ? null
          : () async {
              await widget.onCreateRoom?.call();
            },
      secondaryLabel: 'Retour',
      onSecondary: widget.onBack,
      trailing: isLoading
          ? const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          : null,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.errorText,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 56, color: AppColors.primary),
                  AppSpacing.gapMd,
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (errorText != null) ...[
                    AppSpacing.gapMd,
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  if (trailing != null) trailing!,
                  AppSpacing.gapLg,
                  FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    AppSpacing.gapSm,
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}