import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_model.dart';
import 'diagnostic_notifier.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/diagnostic_progress_bar.dart';
import 'widgets/diagnostic_result_card.dart';

final subjectsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('subjects').limit(100).snapshots().map((snap) {
    final names = <String>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final isActive = (data['isActive'] as bool?) ?? true;
      if (!isActive) continue;

      final name = (data['name'] ?? doc.id).toString().trim();
      if (name.isNotEmpty) names.add(name);
    }

    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  });
});

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();

  bool _started = false;
  bool _assessmentSaved = false;

  static const _grades = [
    'CP',
    'CE1',
    'CE2',
    'CM1',
    'CM2',
    '6e',
    '5e',
    '4e',
    '3e',
    '2nde',
    '1ere',
    'Terminale',
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveAssessment(DiagnosticState state) async {
    if (_assessmentSaved || state.summary == null) return;

    final auth = ref.read(firebaseAuthProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final assessment = AssessmentModel(
      id: '',
      studentId: uid,
      subject: state.subject,
      gradeLevel: state.gradeLevel,
      sessionId: state.sessionId,
      estimatedLevel: state.summary!.estimatedLevel,
      strengths: state.summary!.strengths,
      gaps: state.summary!.gaps,
      recommendedTopics: state.summary!.recommendedTopics,
      questionCount: state.questionCount,
      completedAt: DateTime.now(),
    );

    try {
      await ref.read(assessmentRepositoryProvider).saveAssessment(assessment);
      _assessmentSaved = true;
    } catch (e) {
      // Raison : on ne bloque pas l'utilisateur sur un echec de persistance.
      debugPrint('diagnostic: save assessment failed: $e');
    }
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _inputCtrl.clear();
    ref.read(diagnosticProvider.notifier).sendMessage(text);
  }

  void _retry() {
    final last = ref.read(diagnosticProvider.notifier).lastUserMessage;
    if (last == null || last.isEmpty) return;
    ref.read(diagnosticProvider.notifier).sendMessage(last);
  }

  void _skipDiagnostic(BuildContext context) {
    context.go('/student/dashboard');
  }

  void _navigateToDashboard(BuildContext context) {
    // Raison : go() empeche le retour accidental vers le diagnostic termine.
    context.go('/student/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DiagnosticState>(diagnosticProvider, (prev, next) {
      final previousLength = prev?.messages.length ?? 0;
      final previousLoading = prev?.isLoading ?? false;

      if (next.messages.length != previousLength || next.isLoading != previousLoading) {
        _scrollToBottom();
      }

      final becameComplete = next.isComplete && !(prev?.isComplete ?? false);
      if (becameComplete && next.summary != null) {
        _saveAssessment(next);
      }
    });

    final state = ref.watch(diagnosticProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluation diagnostique'),
        actions: [
          if (_started && !state.isComplete)
            TextButton(
              onPressed: () => _skipDiagnostic(context),
              child: const Text(
                'Passer',
                style: TextStyle(color: AppColors.grey600),
              ),
            ),
        ],
      ),
      body: _started ? _chatView(state) : _setupView(state),
    );
  }

  Widget _setupView(DiagnosticState state) {
    final subjectsAsync = ref.watch(subjectsProvider);

    const fallbackSubjects = [
      'Mathematiques',
      'Physique-Chimie',
      'Francais',
      'Anglais',
      'SVT',
      'Histoire-Geographie',
    ];

    final dynamicSubjects = subjectsAsync.valueOrNull;
    final subjects = (dynamicSubjects == null || dynamicSubjects.isEmpty)
        ? fallbackSubjects
        : dynamicSubjects;

    final selectedSubject = subjects.contains(state.subject) ? state.subject : subjects.first;

    if (selectedSubject != state.subject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(diagnosticProvider.notifier).setSubject(selectedSubject);
      });
    }

    final selectedGrade = _grades.contains(state.gradeLevel) ? state.gradeLevel : _grades.first;

    if (selectedGrade != state.gradeLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(diagnosticProvider.notifier).setGradeLevel(selectedGrade);
      });
    }

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.gapLg,
          const Icon(
            Icons.psychology_outlined,
            size: 64,
            color: AppColors.primary,
          ),
          AppSpacing.gapMd,
          Text(
            'Evaluation de votre niveau',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
          Text(
            'L\'IA va vous poser quelques questions pour personnaliser votre parcours.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.grey600),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapXl,
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedSubject,
            decoration: const InputDecoration(labelText: 'Matiere principale'),
            items: subjects
                .map((subject) => DropdownMenuItem(
                      value: subject,
                      child: Text(subject),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(diagnosticProvider.notifier).setSubject(value);
            },
          ),
          AppSpacing.gapMd,
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedGrade,
            decoration: const InputDecoration(labelText: 'Classe'),
            items: _grades
                .map((grade) => DropdownMenuItem(value: grade, child: Text(grade)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(diagnosticProvider.notifier).setGradeLevel(value);
            },
          ),
          if (subjectsAsync.isLoading) ...[
            AppSpacing.gapSm,
            const LinearProgressIndicator(minHeight: 2),
          ],
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Commencer l\'evaluation'),
            onPressed: state.isLoading
                ? null
                : () async {
              setState(() => _started = true);
              await ref.read(diagnosticProvider.notifier).startDiagnostic();
            },
          ),
          AppSpacing.gapMd,
          TextButton(
            onPressed: () => _skipDiagnostic(context),
            child: const Text('Passer pour l\'instant'),
          ),
        ],
      ),
    );
  }

  Widget _chatView(DiagnosticState state) {
    if (state.isComplete) {
      return _completionView(state);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DiagnosticProgressBar(
            current: state.questionCount,
            max: DiagnosticNotifier.maxQuestions,
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: AppSpacing.pagePadding,
            itemCount: state.messages.length + (state.isLoading ? 1 : 0),
            itemBuilder: (_, index) {
              if (index == state.messages.length) {
                return const ChatBubble(
                  text: '',
                  isUser: false,
                  isLoading: true,
                );
              }

              final message = state.messages[index];
              return ChatBubble(
                text: message['content'] ?? '',
                isUser: message['role'] == 'user',
              );
            },
          ),
        ),
        if (state.hasError)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _retry,
                  child: const Text('Reessayer'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  onSubmitted: (_) => _send(),
                  enabled: !state.isLoading,
                  decoration: InputDecoration(
                    hintText: 'Votre reponse...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor:
                    state.isLoading ? AppColors.grey400 : AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: state.isLoading ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _completionView(DiagnosticState state) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          AppSpacing.gapLg,
          Text(
            'Evaluation terminee !',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
          Text(
            'Votre profil d\'apprentissage a ete cree.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          AppSpacing.gapLg,
          if (state.summary != null)
            DiagnosticResultCard(summary: state.summary!)
          else
            Card(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Text(
                  'Resultats non disponibles.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          AppSpacing.gapLg,
          ElevatedButton.icon(
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Acceder a mon tableau de bord'),
            onPressed: () => _navigateToDashboard(context),
          ),
        ],
      ),
    );
  }
}
