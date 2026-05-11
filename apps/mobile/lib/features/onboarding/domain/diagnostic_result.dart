import 'dart:convert';

import 'package:flutter/material.dart';

class DiagnosticTurn {
  const DiagnosticTurn({
    required this.question,
    required this.feedback,
    required this.isComplete,
    required this.summary,
  });

  final String? question;
  final String? feedback;
  final bool isComplete;
  final DiagnosticSummary? summary;

  factory DiagnosticTurn.fromJson(Map<String, dynamic> json) {
    return DiagnosticTurn(
      question: (json['question'] as String?)?.trim(),
      feedback: (json['feedback'] as String?)?.trim(),
      isComplete: json['is_complete'] == true,
      summary: json['summary'] is Map<String, dynamic>
          ? DiagnosticSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  static DiagnosticTurn fromRawString(String raw) {
    var clean = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    if (clean.isEmpty) {
      throw const FormatException('Réponse vide du serveur de diagnostic');
    }

    try {
      final parsed = jsonDecode(clean) as Map<String, dynamic>;
      return DiagnosticTurn.fromJson(parsed);
    } on FormatException {
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');

      if (start != -1 && end != -1 && end > start) {
        final slice = clean.substring(start, end + 1);
        try {
          final parsed = jsonDecode(slice) as Map<String, dynamic>;
          return DiagnosticTurn.fromJson(parsed);
        } on FormatException {
          // Fallback: si le LLM renvoie du texte libre, on l'affiche comme prochaine question.
        }
      }

      return DiagnosticTurn(
        question: clean,
        feedback: null,
        isComplete: false,
        summary: null,
      );
    }
  }
}

class DiagnosticSummary {
  const DiagnosticSummary({
    required this.strengths,
    required this.gaps,
    required this.recommendedTopics,
    required this.estimatedLevel,
  });

  final List<String> strengths;
  final List<String> gaps;
  final List<String> recommendedTopics;
  final String estimatedLevel;

  factory DiagnosticSummary.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) => item.toString()).toList();
    }

    return DiagnosticSummary(
      strengths: parseList(json['strengths']),
      gaps: parseList(json['gaps']),
      recommendedTopics: parseList(json['recommended_topics']),
      estimatedLevel: (json['estimated_level'] ?? 'debutant').toString(),
    );
  }

  Color get levelColor => switch (estimatedLevel.toLowerCase()) {
        'avance' || 'avancé' => Colors.green,
        'intermediaire' || 'intermédiaire' => Colors.orange,
        'debutant' || 'débutant' => Colors.red,
        _ => Colors.blue,
      };

  IconData get levelIcon => switch (estimatedLevel.toLowerCase()) {
        'avance' || 'avancé' => Icons.military_tech_outlined,
        'intermediaire' || 'intermédiaire' => Icons.trending_up_outlined,
        _ => Icons.school_outlined,
      };
}
