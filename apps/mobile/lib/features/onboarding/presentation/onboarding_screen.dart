import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen
//
// Shown once after first registration to:
// 1. Let the user select their role (student / parent)
// 2. Collect minimal profile data
//
// Role escalation to tutor/staff requires a separate admin approval flow.
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  UserRole? _selectedRole;
  int       _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.gapLg,
              Text(
                'Bienvenue sur Suklu !',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                'Comment allez-vous utiliser Suklu ?',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXl,

              _RoleCard(
                role:     UserRole.student,
                icon:     Icons.school_outlined,
                title:    'Je suis étudiant',
                subtitle: 'Accède à des tuteurs et à l\'IA pour progresser',
                color:    AppColors.studentAccent,
                selected: _selectedRole == UserRole.student,
                onTap:    () => setState(() => _selectedRole = UserRole.student),
              ),
              AppSpacing.gapMd,

              _RoleCard(
                role:     UserRole.parent,
                icon:     Icons.family_restroom_outlined,
                title:    'Je suis parent',
                subtitle: 'Gérez les cours et suivez les progrès de votre enfant',
                color:    AppColors.parentAccent,
                selected: _selectedRole == UserRole.parent,
                onTap:    () => setState(() => _selectedRole = UserRole.parent),
              ),
              AppSpacing.gapMd,

              _RoleCard(
                role:     UserRole.tutor,
                icon:     Icons.person_outlined,
                title:    'Je suis tuteur',
                subtitle: 'Donnez des cours et créez des ressources pédagogiques',
                color:    AppColors.tutorAccent,
                selected: _selectedRole == UserRole.tutor,
                onTap:    () => setState(() => _selectedRole = UserRole.tutor),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _selectedRole == null
                    ? null
                    : () {
                        // TODO: call a Cloud Function to update the user's role
                        // and navigate to the appropriate dashboard
                        final home = switch (_selectedRole) {
                          UserRole.student => '/student/dashboard',
                          UserRole.parent  => '/parent/dashboard',
                          UserRole.tutor   => '/tutor/dashboard',
                          _                => '/student/dashboard',
                        };
                        context.go(home);
                      },
                child: const Text('Continuer'),
              ),
              AppSpacing.gapMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(25) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: selected ? color : AppColors.grey200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600)),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle, color: color),
        ],
      ),
    ),
  );
}
