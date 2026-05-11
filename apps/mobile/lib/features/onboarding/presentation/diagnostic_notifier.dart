import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_tutor/data/ai_tutor_repository.dart';
import '../domain/diagnostic_result.dart';

class DiagnosticState {
  const DiagnosticState({
    this.messages = const [],
    this.currentQuestion = '',
    this.isLoading = false,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage = '',
    this.subject = 'Mathématiques',
    this.gradeLevel = 'Terminale',
    this.questionCount = 0,
    this.summary,
    this.sessionId = '',
  });

  final List<Map<String, String>> messages;
  final String currentQuestion;
  final bool isLoading;
  final bool isComplete;
  final bool hasError;
  final String errorMessage;
  final String subject;
  final String gradeLevel;
  final int questionCount;
  final DiagnosticSummary? summary;
  final String sessionId;

  DiagnosticState copyWith({
    List<Map<String, String>>? messages,
    String? currentQuestion,
    bool? isLoading,
    bool? isComplete,
    bool? hasError,
    String? errorMessage,
    String? subject,
    String? gradeLevel,
    int? questionCount,
    DiagnosticSummary? summary,
    bool clearSummary = false,
    String? sessionId,
  }) {
    return DiagnosticState(
      messages: messages ?? this.messages,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      questionCount: questionCount ?? this.questionCount,
      summary: clearSummary ? null : (summary ?? this.summary),
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class DiagnosticNotifier extends StateNotifier<DiagnosticState> {
  DiagnosticNotifier(this._aiRepo)
      : _sessionId = 'diag_${DateTime.now().millisecondsSinceEpoch}',
        super(const DiagnosticState()) {
    state = state.copyWith(sessionId: _sessionId);
  }

  final AiTutorRepository _aiRepo;
  final String _sessionId;

  static const maxQuestions = 10;

  void setSubject(String value) => state = state.copyWith(subject: value);

  void setGradeLevel(String value) => state = state.copyWith(gradeLevel: value);

  String? get lastUserMessage {
    for (final message in state.messages.reversed) {
      if (message['role'] == 'user') return message['content'];
    }
    return null;
  }

  Future<void> sendMessage(String userMessage) async {
    final text = userMessage.trim();
    if (text.isEmpty) return;

    final updated = [
      ...state.messages,
      {'role': 'user', 'content': text},
    ];

    state = state.copyWith(
      messages: updated,
      isLoading: true,
      hasError: false,
      errorMessage: '',
    );

    try {
      final result = await _aiRepo.startDiagnostic(
        subject: state.subject,
        gradeLevel: state.gradeLevel,
        sessionId: _sessionId,
        history: updated,
        maxQuestions: maxQuestions,
      );

      final raw = (result['raw'] as String?) ?? '';
      final turn = DiagnosticTurn.fromRawString(raw);

      final chunks = <String>[
        if (turn.feedback != null && turn.feedback!.isNotEmpty) turn.feedback!,
        if (turn.question != null && turn.question!.isNotEmpty) turn.question!,
      ];

      final displayText = chunks.isEmpty
          ? 'Réponse invalide du serveur.'
          : chunks.join('\n\n');

      final updatedWithReply = [
        ...updated,
        {'role': 'assistant', 'content': displayText},
      ];

      state = state.copyWith(
        messages: updatedWithReply,
        isLoading: false,
        isComplete: turn.isComplete,
        summary: turn.summary,
        questionCount: state.questionCount + (turn.question != null ? 1 : 0),
        currentQuestion: turn.question ?? '',
        hasError: false,
        errorMessage: '',
      );
    } on FormatException {
      final updatedWithReply = [
        ...updated,
        const {
          'role': 'assistant',
          'content': 'Réponse invalide du serveur. Veuillez réessayer.'
        },
      ];

      state = state.copyWith(
        messages: updatedWithReply,
        isLoading: false,
        hasError: true,
        errorMessage: 'Réponse invalide du serveur.',
      );
    } on DioException {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Erreur réseau avec le service IA. Réessayez.',
      );
    } on JsonUnsupportedObjectError {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Réponse du serveur non exploitable. Réessayez.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Erreur de communication avec le service IA. Réessayez.',
      );
    }
  }

  Future<void> startDiagnostic() {
    return sendMessage('Bonjour, je veux commencer mon évaluation.');
  }
}

final diagnosticProvider =
    StateNotifierProvider.autoDispose<DiagnosticNotifier, DiagnosticState>(
  (ref) => DiagnosticNotifier(ref.read(aiTutorRepositoryProvider)),
);
