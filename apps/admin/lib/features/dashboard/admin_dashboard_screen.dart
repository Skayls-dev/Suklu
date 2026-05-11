import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminDashboardScreen
//
// Homepage pour le Super Admin — grille de cartes pour accéder aux sections.
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const _sections = [
    (
      icon: Icons.school_outlined,
      color: Colors.blue,
      title: 'Gestion des tuteurs',
      subtitle: 'Approuver/rejeter candidatures',
      path: '/applications',
    ),
    (
      icon: Icons.people_outlined,
      color: Colors.green,
      title: 'Utilisateurs',
      subtitle: 'Rôles, suspension, recherche',
      path: '/users',
    ),
    (
      icon: Icons.attach_money_outlined,
      color: Colors.purple,
      title: 'Paiements',
      subtitle: 'Relevés, remboursements',
      path: '/payments',
    ),
    (
      icon: Icons.video_call_outlined,
      color: Colors.orange,
      title: 'Sessions',
      subtitle: 'Suivi & support',
      path: '/sessions',
    ),
    (
      icon: Icons.family_restroom_outlined,
      color: Colors.pink,
      title: 'Liaisons parent-étudiant',
      subtitle: 'Demandes de liaison',
      path: '/link-requests',
    ),
    (
      icon: Icons.book_outlined,
      color: Colors.teal,
      title: 'Modération',
      subtitle: 'Signalements et contenu',
      path: '/content',
    ),
    (
      icon: Icons.settings_outlined,
      color: Colors.grey,
      title: 'Configurations',
      subtitle: 'Prix, matières, horaires',
      path: '/config',
    ),
    (
      icon: Icons.bug_report_outlined,
      color: Colors.red,
      title: 'Logs & Erreurs',
      subtitle: 'Système et support',
      path: '/logs',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord admin'),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _sections.length,
          itemBuilder: (context, idx) {
            final section = _sections[idx];
            return _SectionCard(
              icon: section.icon,
              color: section.color,
              title: section.title,
              subtitle: section.subtitle,
              onTap: () => context.go(section.path),
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
