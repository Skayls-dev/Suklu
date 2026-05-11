import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

mixin OfflineGuardMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Future<void> guardOnline(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action impossible hors ligne. Reconnectez-vous.'),
        ),
      );
      return;
    }

    await action();
  }
}
