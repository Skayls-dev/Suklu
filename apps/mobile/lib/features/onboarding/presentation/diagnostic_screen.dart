import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../ai_tutor/data/ai_tutor_repository.dart';


// ── State ──────────────────────────────────────────────────────────────────────
final _diagnosticChatProvider =
    StateNotifierProvider.autoDispose<_DiagnosticNotifier, _DiagnosticState>(
  (ref) => _DiagnosticNotifier(ref.read(aiTutorRepositoryProvider)),
);

class _DiagnosticState {
  const _DiagnosticState({
    this.messages   = const [],
    this.isLoading  = false,
    this.isComplete = false,
    this.subject    = 'Mathématiques',
    this.gradeLevel = '3ème',
  });
  final List<Map<String, String>> messages;
  final bool   isLoading;
  final bool   isComplete;
  final String subject;
  final String gradeLevel;

  _DiagnosticState copyWith({
    List<Map<String, String>>? messages,
    bool? isLoading,
    bool? isComplete,
    String? subject,
    String? gradeLevel,
  }) => _DiagnosticState(
    messages:   messages   ?? this.messages,
    isLoading:  isLoading  ?? this.isLoading,
    isComplete: isComplete ?? this.isComplete,
    subject:    subject    ?? this.subject,
    gradeLevel: gradeLevel ?? this.gradeLevel,
  );
}

class _DiagnosticNotifier extends StateNotifier<_DiagnosticState> {
  _DiagnosticNotifier(this._repo) : super(const _DiagnosticState());

  final AiTutorRepository _repo;

  void setSubject(String s)    => state = state.copyWith(subject:    s);
  void setGradeLevel(String g) => state = state.copyWith(gradeLevel: g);

  Future<void> startOrContinue(String userMessage) async {
    final updated = [...state.messages, {'role': 'user', 'content': userMessage}];
    state = state.copyWith(messages: updated, isLoading: true);

    final result = await _repo.startDiagnostic(
      subject:    state.subject,
      gradeLevel: state.gradeLevel,
      sessionId:  'diag_${DateTime.now().millisecondsSinceEpoch}',
      history:    updated,
    );

    final reply = result['raw'] as String? ?? result['reply'] as String? ?? '';
    final isDone = reply.toLowerCase().contains('résumé') ||
        reply.toLowerCase().contains('évaluation terminée') ||
        updated.length >= 22; // ~11 Q&A pairs max

    state = state.copyWith(
      messages:   [...updated, {'role': 'assistant', 'content': reply}],
      isLoading:  false,
      isComplete: isDone,
    );
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl  = TextEditingController();
  bool  _started    = false;

  static const _subjects = [
    'Mathématiques', 'Physique-Chimie', 'Français', 'Anglais', 'SVT', 'Histoire-Géo'
  ];
  static const _grades = [
    '6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Terminale'
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    ref.read(_diagnosticChatProvider.notifier).startOrContinue(text);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_diagnosticChatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Évaluation diagnostique'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_started)
            const SizedBox.shrink()
          else
            TextButton(
              onPressed: () => _skipDiagnostic(context),
              child: const Text('Passer', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: _started ? _chatView(state) : _setupView(state),
    );
  }

  Widget _setupView(_DiagnosticState state) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.gapLg,
          const Icon(Icons.psychology_outlined, size: 64, color: AppColors.primary),
          AppSpacing.gapMd,
          Text(
            'Évaluation de votre niveau',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
          Text(
            'L\'IA va vous poser quelques questions pour personnaliser votre parcours.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.grey600),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapXl,

          DropdownButtonFormField<String>(
            value: state.subject,
            decoration: const InputDecoration(labelText: 'Matière principale'),
            items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => ref.read(_diagnosticChatProvider.notifier).setSubject(v!),
          ),
          AppSpacing.gapMd,

          DropdownButtonFormField<String>(
            value: state.gradeLevel,
            decoration: const InputDecoration(labelText: 'Classe'),
            items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => ref.read(_diagnosticChatProvider.notifier).setGradeLevel(v!),
          ),
          const Spacer(),

          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Commencer l\'évaluation'),
            onPressed: () async {
              setState(() => _started = true);
              await ref.read(_diagnosticChatProvider.notifier)
                  .startOrContinue('Bonjour, je veux commencer mon évaluation.');
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

  Widget _chatView(_DiagnosticState state) {
    if (state.isComplete) {
      return _completionView(state);
    }

    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: AppSpacing.pagePadding,
          itemCount: state.messages.length + (state.isLoading ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == state.messages.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: AppColors.primary,
                    child: Icon(Icons.psychology_outlined, color: Colors.white, size: 16)),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: LinearProgressIndicator(color: AppColors.primary),
                  ),
                ]),
              );
            }
            final msg  = state.messages[i];
            final isUser = msg['role'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  msg['content'] ?? '',
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Votre réponse...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: state.isLoading ? null : _send,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _completionView(_DiagnosticState state) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          AppSpacing.gapLg,
          Text(
            'Évaluation terminée !',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
          Text(
            'Votre profil d\'apprentissage a été créé. Vos cours seront personnalisés en conséquence.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          AppSpacing.gapXl,
          ElevatedButton(
            onPressed: () => context.go('/student/dashboard'),
            child: const Text('Accéder à mon espace'),
          ),
        ],
      ),
    );
  }

  void _skipDiagnostic(BuildContext context) {
    context.go('/student/dashboard');
  }
}
