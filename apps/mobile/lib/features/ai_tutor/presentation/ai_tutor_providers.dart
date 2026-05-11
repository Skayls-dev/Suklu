import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_tutor_repository.dart';

// Chat message model
class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final String role;    // 'user' | 'assistant'
  final String content;

  Map<String, String> toMap() => {'role': role, 'content': content};

  ChatMessage copyWith({String? role, String? content}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }
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

    state = [
      ...state,
      ChatMessage(role: 'user', content: text),
      const ChatMessage(role: 'assistant', content: ''),
    ];
    isLoading = true;

    try {
      var streamedReply = '';
      await for (final chunk in ref.read(aiTutorRepositoryProvider).streamChat(
        message: text,
        subject: subject,
        gradeLevel: gradeLevel,
        sessionId: sessionId,
        history: state
            .where((m) => m.content.isNotEmpty)
            .map((m) => m.toMap())
            .toList(),
      )) {
        streamedReply += chunk;
        final updated = [...state];
        final last = updated.last;
        updated[updated.length - 1] = last.copyWith(content: streamedReply);
        state = updated;
      }

      if (streamedReply.isEmpty) {
        final updated = [...state];
        updated[updated.length - 1] = updated.last.copyWith(
          content: 'Désolé, aucune réponse n\'a été reçue.',
        );
        state = updated;
      }
    } catch (_) {
      final updated = [...state];
      updated[updated.length - 1] = updated.last.copyWith(
        content: 'Connexion impossible au service IA. Vérifiez votre connexion.',
      );
      state = updated;
    } finally {
      isLoading = false;
    }
  }

  void clearHistory() => state = [];
}
