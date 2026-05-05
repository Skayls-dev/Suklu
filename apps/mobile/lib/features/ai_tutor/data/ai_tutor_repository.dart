import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

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

  Future<Map<String, dynamic>> startDiagnostic({
    required String subject,
    required String gradeLevel,
    required String sessionId,
    List<Map<String, String>> history = const [],
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
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout:    const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return {
          'reply': '🚧 [Mode démo] Service IA non disponible. Lancez le gateway localement pour activer le diagnostic.',
        };
      }
      rethrow;
    }
  }
}

final aiTutorRepositoryProvider = Provider<AiTutorRepository>((ref) {
  return AiTutorRepository(auth: ref.watch(firebaseAuthProvider));
});
