import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/payment_repository.dart';
import '../domain/payment_model.dart';

final userPaymentsProvider = StreamProvider.autoDispose<List<PaymentModel>>((ref) {
  final user = ref.watch(authStateNotifierProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(paymentRepositoryProvider).watchPaymentsForUser(user.uid);
});
