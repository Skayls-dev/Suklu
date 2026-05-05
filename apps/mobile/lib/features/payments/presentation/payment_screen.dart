import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../domain/payment_model.dart';
import 'payment_providers.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(userPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des paiements')),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (payments) => payments.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: AppSpacing.pagePadding,
                itemCount: payments.length,
                itemBuilder: (context, i) => _PaymentTile(payment: payments[i]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.grey400),
      SizedBox(height: 16),
      Text('Aucun paiement', style: TextStyle(color: AppColors.grey600)),
    ]),
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final PaymentModel payment;

  Color get _statusColor => switch (payment.status) {
    PaymentStatus.success  => AppColors.success,
    PaymentStatus.failed   => AppColors.error,
    PaymentStatus.refunded => AppColors.warning,
    PaymentStatus.pending  => AppColors.grey600,
  };

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor.withAlpha(30),
        child: Icon(Icons.payment, color: _statusColor),
      ),
      title: Text(payment.formattedAmount,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${payment.providerLabel} · ${payment.statusLabel}'),
      trailing: Text(
        '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
        style: const TextStyle(fontSize: 12, color: AppColors.grey600),
      ),
    ),
  );
}
