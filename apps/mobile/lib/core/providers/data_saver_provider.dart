import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _dataSaverStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
  name: 'dataSaverStorageProvider',
);

final dataSaverProvider = StateProvider<bool>(
  (_) => false,
  name: 'dataSaverProvider',
);

final dataSaverBootstrapProvider = FutureProvider<void>((ref) async {
  final storage = ref.watch(_dataSaverStorageProvider);
  final raw = await storage.read(key: 'data_saver_mode');
  ref.read(dataSaverProvider.notifier).state = raw == 'true';
});

Future<void> setDataSaverEnabled(WidgetRef ref, bool enabled) async {
  ref.read(dataSaverProvider.notifier).state = enabled;
  final storage = ref.read(_dataSaverStorageProvider);
  await storage.write(key: 'data_saver_mode', value: enabled ? 'true' : 'false');
}
