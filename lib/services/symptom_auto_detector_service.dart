import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lifelens/app_services.dart';

/// Symptoms auto-detector and keyword matcher.
/// Detects symptom keywords from explicit symptom text and tracks frequency.
class SymptomAutoDetectorService {
  /// Common symptom keywords and their variations.
  static const Map<String, List<String>> symptomKeywords = {
    'headache': ['headache', 'head ache', 'head pain', 'migraines', 'migraine'],
    'nausea': ['nausea', 'nauseous', 'queasy'],
    'fatigue': ['fatigue', 'tired', 'exhausted', 'exhaustion', 'energy loss'],
    'fever': ['fever', 'feverish', 'high temperature'],
    'cough': ['cough', 'coughing', 'persistent cough'],
    'sore throat': ['sore throat', 'throat pain', 'throat ache', 'pharyngitis'],
    'congestion': [
      'congestion',
      'congested',
      'stuffy nose',
      'nasal congestion',
    ],
    'runny nose': ['runny nose', 'runny', 'rhinitis'],
    'sneezing': ['sneezing', 'sneeze', 'sneezes'],
    'shivers': ['shivers', 'shivering', 'chills'],
    'body ache': [
      'body ache',
      'muscle ache',
      'muscle pain',
      'aches',
      'myalgia',
    ],
    'dizziness': ['dizziness', 'dizzy', 'vertigo'],
    'back pain': ['back pain', 'backache', 'lower back pain'],
    'neck pain': ['neck pain', 'neck ache', 'stiff neck'],
    'joint pain': ['joint pain', 'arthralgia'],
    'stomach pain': [
      'stomach pain',
      'stomach ache',
      'abdominal pain',
      'belly pain',
    ],
    'diarrhea': ['diarrhea', 'diarrhoea', 'loose stool', 'loose stools'],
    'constipation': ['constipation', 'constipated'],
    'rash': ['rash', 'skin rash', 'hives'],
    'anxiety': ['anxiety', 'anxious', 'worried', 'nervous'],
    'depression': ['depression', 'depressed', 'sad', 'sadness'],
    'insomnia': [
      'insomnia',
      'cannot sleep',
      'can\'t sleep',
      'trouble sleeping',
    ],
    'sleep issues': ['sleep issues', 'sleeping badly', 'poor sleep'],
    'brain fog': ['brain fog', 'foggy', 'confusion', 'confused', 'mental fog'],
    'memory issues': ['memory issues', 'forgetfulness', 'forgetting'],
    'swelling': ['swelling', 'swollen', 'edema'],
    'shortness of breath': [
      'shortness of breath',
      'short of breath',
      'breathless',
      'difficulty breathing',
    ],
    'chest pain': [
      'chest pain',
      'chest ache',
      'chest pressure',
      'chest discomfort',
      'heart pain',
      'heart ache',
    ],
    'palpitations': ['palpitations', 'heart pounding', 'irregular heartbeat'],
    'weakness': ['weakness', 'weak', 'feeling weak'],
  };

  /// Detects symptoms from free-form text and returns list of matched symptoms.
  static List<String> detectSymptomsFromText(String text) {
    final lowerText = text.toLowerCase().trim();
    if (lowerText.isEmpty) return [];

    final detected = <String>{};

    // Match keywords
    for (final entry in symptomKeywords.entries) {
      final canonical = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        // Use word boundaries to avoid partial matches
        // e.g., 'tired' shouldn't match in 'tiredx'
        final pattern = RegExp(
          r'\b' + RegExp.escape(keyword) + r'\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(lowerText)) {
          detected.add(canonical);
          break;
        }
      }
    }

    return detected.toList();
  }

  /// Auto-registration is intentionally disabled.
  ///
  /// Symptom entries should only be created by the explicit symptom logger so
  /// mood, sleep, exercise, and chat text do not create inaccurate checkups.
  static Future<bool> autoRegisterDetectedSymptoms(
    String sourceText,
    String source, // e.g., 'mood_log', 'chat_history'
  ) async {
    return false;
  }

  /// Gets all symptoms with their frequency counts (sorted by frequency descending).
  static Future<List<SymptomFrequency>> getSymptomFrequencies() async {
    try {
      final entries = await AppServices.isar.getAllSymptomEntries();

      final counts = <String, int>{};

      for (final entry in entries) {
        final predicted = entry.predictedAilment.trim().toLowerCase();
        final resolver = entry.resolvedBy.trim().toLowerCase();
        if (predicted == 'auto-detected' || resolver == 'auto_detector') {
          continue;
        }
        for (final symptom in entry.symptomList) {
          final normalized = symptom.trim().toLowerCase();
          if (normalized.isNotEmpty) {
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }

      final items =
          counts.entries
              .map((e) => SymptomFrequency(symptom: e.key, count: e.value))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));

      return items;
    } catch (e) {
      debugPrint('Error getting symptom frequencies: $e');
      return [];
    }
  }

  /// Gets frequency count for a specific symptom.
  static Future<int> getSymptomCount(String symptom) async {
    try {
      final entries = await AppServices.isar.getAllSymptomEntries();

      final normalized = symptom.trim().toLowerCase();
      int count = 0;

      for (final entry in entries) {
        final predicted = entry.predictedAilment.trim().toLowerCase();
        final resolver = entry.resolvedBy.trim().toLowerCase();
        if (predicted == 'auto-detected' || resolver == 'auto_detector') {
          continue;
        }
        for (final s in entry.symptomList) {
          if (s.trim().toLowerCase() == normalized) {
            count += 1;
            break; // Count each entry only once per symptom
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint('Error getting symptom count: $e');
      return 0;
    }
  }
}

/// Single symptom frequency record.
class SymptomFrequency {
  const SymptomFrequency({required this.symptom, required this.count});

  final String symptom;
  final int count;
}
