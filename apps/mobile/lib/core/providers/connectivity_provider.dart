import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((_) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((event) {
    return _hasConnection(event);
  });
});

final isOnlineProvider = Provider<bool>((ref) {
  final state = ref.watch(connectivityProvider);
  return state.maybeWhen(data: (isOnline) => isOnline, orElse: () => true);
});

Future<bool> checkOnlineNow() async {
  final result = await Connectivity().checkConnectivity();
  return _hasConnection(result);
}

bool _hasConnection(Object result) {
  if (result is ConnectivityResult) {
    return result != ConnectivityResult.none;
  }
  if (result is List<ConnectivityResult>) {
    return result.any((entry) => entry != ConnectivityResult.none);
  }
  return true;
}
