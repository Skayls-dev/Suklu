import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../shared/providers/admin_stats_provider.dart';
import '../shared/widgets/stat_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userStatsProvider);
    final monthlyRevenue = ref.watch(monthlyRevenueProvider);
    final monthlySessions = ref.watch(monthlySessionsProvider);
    final pendingApplications = ref.watch(pendingApplicationsCountProvider);
    final pendingFlagged = ref.watch(pendingFlaggedCountProvider);

    String metric<T>(AsyncValue<T> value, String Function(T data) mapper) {
      return value.when(data: mapper, loading: () => '...', error: (_, __) => 'Err.');
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userStatsProvider);
        ref.invalidate(monthlyRevenueProvider);
        ref.invalidate(monthlySessionsProvider);
        ref.invalidate(pendingApplicationsCountProvider);
        ref.invalidate(pendingFlaggedCountProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tableau de bord', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              DateFormat('EEEE d MMMM yyyy', 'fr').format(DateTime.now()),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                StatCard(
                  label: 'Étudiants actifs',
                  value: metric(userStats, (d) => '${d['student'] ?? 0}'),
                  icon: Icons.school,
                  color: Colors.blue,
                ),
                StatCard(
                  label: 'Tuteurs actifs',
                  value: metric(userStats, (d) => '${d['tutor'] ?? 0}'),
                  icon: Icons.person,
                  color: const Color(0xFF1A6B4A),
                ),
                StatCard(
                  label: 'Sessions ce mois',
                  value: metric(monthlySessions, (d) => '$d'),
                  icon: Icons.video_call,
                  color: Colors.purple,
                ),
                StatCard(
                  label: 'Revenus (XOF)',
                  value: metric(monthlyRevenue, (d) => (d['XOF'] ?? 0).toStringAsFixed(0)),
                  icon: Icons.payments,
                  color: Colors.orange,
                ),
                StatCard(
                  label: 'Demandes en attente',
                  value: metric(pendingApplications, (d) => '$d'),
                  icon: Icons.pending,
                  color: Colors.red,
                ),
                StatCard(
                  label: 'Contenus signalés',
                  value: metric(pendingFlagged, (d) => '$d'),
                  icon: Icons.flag,
                  color: Colors.deepOrange,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Actions rapides', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.go('/applications'),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Voir demandes tuteurs'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/content'),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Modérer le contenu'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/link-requests'),
                  icon: const Icon(Icons.family_restroom_outlined),
                  label: const Text('Liaison parent-enfant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
