import 'package:logger/logger.dart';

// Single app-wide logger instance.
// In production builds, filter below Warning to reduce log noise.
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
  level: const bool.fromEnvironment('dart.vm.product') ? Level.warning : Level.trace,
);
