import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/chat_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiTutorRepository
//
// Communicates with the Cloud Run AI Gateway.
// The Firebase ID token is attached to every request so the gateway can
// verify the caller and enforce its own RBAC (e.g., quiz only for tutors).
//
// Gateway base URL is intentionally NOT in client code — it is fetched from
// Firebase Remote Config so it can be rotated without an app update.
// For the MVP, it is hardcoded as a const that you override per environment.
// ─────────────────────────────────────────────────────────────────────────────
const _gatewayBaseUrl = String.fromEnvironment(
  'AI_GATEWAY_URL',
  defaultValue: 'http://localhost:8000',
);

class AiTutorRepository {
  AiTutorRepository({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;
  late final _dio    = Dio(BaseOptions(baseUrl: _gatewayBaseUrl));

  Future<Map<String, dynamic>> sendChat({
    required String       message,
    required String       subject,
    required String       gradeLevel,
    required String       sessionId,
    required List<Map<String, String>> history,
    bool includeImages = true,
    String                country = 'Sénégal',
  }) async {
    final token    = await _auth.currentUser!.getIdToken();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat',
        data: {
          'message':              message,
          'subject':              subject,
          'grade_level':          gradeLevel,
          'country':              country,
          'conversation_history': history,
          'session_id':           sessionId,
          'include_images':       includeImages,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout:    const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      // Gateway not running locally — return a mock response for dev
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return {
          'reply':
              '🚧 **[Mode démo - Connexion impossible]**\n\n'
              'Le gateway IA ne répond pas sur `localhost:8000`.\n\n'
              '**Pour activer le vrai tuteur IA :**\n\n'
              '1. Ouvre un nouveau terminal\n'
              '2. Lance :\n'
              '```\n'
              'cd suklu\\backend\\ai-gateway\n'
              'cmd /c ".venv\\Scripts\\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000"\n'
              '```\n\n'
              '**Erreur détail :** ${e.message}',
        };
      }
      
      // Other errors (500, 400, etc) — show detailed error
      if (e.response != null) {
        return {
          'reply':
              '❌ **Erreur du serveur**\n\n'
              'Code: ${e.response!.statusCode}\n\n'
              '${e.response!.data}',
        };
      }
      
      // Generic error
      return {
        'reply': '❌ **Erreur de communication**\n\n'
                '${e.message}\n\n'
                'Type: ${e.type}',
      };
    }
  }

  Stream<String> streamChat({
    required String message,
    required String subject,
    required String gradeLevel,
    required String sessionId,
    required List<Map<String, String>> history,
    required bool includeImages,
    void Function(List<ChatImageRef> images)? onImages,
    String country = 'Sénégal',
  }) async* {
    final token = await _auth.currentUser!.getIdToken();

    final response = await _dio.post<ResponseBody>(
      '/chat/stream',
      data: {
        'message': message,
        'subject': subject,
        'grade_level': gradeLevel,
        'country': country,
        'conversation_history': history,
        'session_id': sessionId,
        'include_images': includeImages,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.stream,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final body = response.data;
    if (body == null) {
      throw Exception('Réponse streaming vide');
    }

    var buffer = '';
    final textStream = utf8.decoder.bind(body.stream.cast<List<int>>());

    await for (final chunk in textStream) {
      buffer += chunk;

      while (true) {
        final boundary = buffer.indexOf('\n\n');
        if (boundary == -1) break;

        final rawEvent = buffer.substring(0, boundary).trim();
        buffer = buffer.substring(boundary + 2);
        if (rawEvent.isEmpty) continue;

        String? event;
        String? data;
        for (final line in rawEvent.split('\n')) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            data = line.substring(5).trim();
          }
        }

        if (data == null || data.isEmpty) continue;
        final payload = jsonDecode(data) as Map<String, dynamic>;

        if (event == 'delta') {
          final text = payload['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } else if (event == 'images') {
          final rawImages = (payload['images'] as List?) ?? const [];
          final parsed = rawImages
              .map((i) {
                final map = Map<String, dynamic>.from(i as Map);
                return ChatImageRef(
                  url: map['url']?.toString() ?? '',
                  caption: map['caption']?.toString() ?? '',
                );
              })
              .where((img) => img.url.isNotEmpty)
              .toList();
          onImages?.call(parsed);
        } else if (event == 'error') {
          throw Exception(payload['message'] ?? 'Erreur du service IA');
        } else if (event == 'done') {
          return;
        }
      }
    }
  }

  Future<Map<String, dynamic>> startDiagnostic({
    required String subject,
    required String gradeLevel,
    required String sessionId,
    List<Map<String, String>> history = const [],
    int maxQuestions = 10,
  }) async {
    final token    = await _auth.currentUser!.getIdToken();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/diagnostic',
        data: {
          'subject':              subject,
          'grade_level':          gradeLevel,
          'session_id':           sessionId,
          'conversation_history': history,
          'max_questions':        maxQuestions,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout:    const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data!;
    } on DioException {
      rethrow;
    }
  }
}

final aiTutorRepositoryProvider = Provider<AiTutorRepository>((ref) {
  return AiTutorRepository(auth: ref.watch(firebaseAuthProvider));
});
