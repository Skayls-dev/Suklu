import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_tutor_repository.dart';

// Chat message model
class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final String role;    // 'user' | 'assistant'
  final String content;

  Map<String, String> toMap() => {'role': role, 'content': content};
}

// ─────────────────────────────────────────────────────────────────────────────
// AiChatNotifier
//
// Manages the full conversation history and handles LLM requests.
// State is a list of messages ordered oldest → newest.
// ─────────────────────────────────────────────────────────────────────────────
final aiChatProvider =
    NotifierProvider<AiChatNotifier, List<ChatMessage>>(AiChatNotifier.new);

class AiChatNotifier extends Notifier<List<ChatMessage>> {
  String subject    = 'Mathématiques';
  String gradeLevel = 'Terminale';
  String sessionId  = '';
  bool   isLoading  = false;

  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    if (isLoading) return;

    state    = [...state, ChatMessage(role: 'user', content: text)];
    isLoading = true;

    try {
      final result = await ref.read(aiTutorRepositoryProvider).sendChat(
        message:    text,
        subject:    subject,
        gradeLevel: gradeLevel,
        sessionId:  sessionId,
        history:    state.map((m) => m.toMap()).toList(),
      );
      final reply = result['reply'] as String? ?? 'Désolé, une erreur est survenue.';
      state = [...state, ChatMessage(role: 'assistant', content: reply)];
    } catch (_) {
      state = [
        ...state,
        const ChatMessage(
          role: 'assistant',
          content: 'Connexion impossible au service IA. Vérifiez votre connexion.',
        ),
      ];
    } finally {
      isLoading = false;
    }
  }

  void clearHistory() => state = [];
}
