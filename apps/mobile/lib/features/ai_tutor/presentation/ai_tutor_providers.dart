import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_saver_provider.dart';
import '../domain/chat_models.dart';
import '../data/ai_tutor_repository.dart';

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
      var streamImages = <ChatImageRef>[];
      await for (final chunk in ref.read(aiTutorRepositoryProvider).streamChat(
        message: text,
        subject: subject,
        gradeLevel: gradeLevel,
        sessionId: sessionId,
        includeImages: !ref.read(dataSaverProvider),
        history: state
            .where((m) => m.content.isNotEmpty)
            .map((m) => m.toMap())
            .toList(),
        onImages: (images) {
          streamImages = images;
        },
      )) {
        streamedReply += chunk;
        final updated = [...state];
        final last = updated.last;
        updated[updated.length - 1] = last.copyWith(content: streamedReply);
        state = updated;
      }

      final (cleanContent, parsedImages) = parseImageReferences(streamedReply);
      final finalImages = streamImages.isNotEmpty ? streamImages : parsedImages;
      if (state.isNotEmpty) {
        final updated = [...state];
        updated[updated.length - 1] = updated.last.copyWith(
          content: cleanContent,
          images: finalImages,
        );
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
