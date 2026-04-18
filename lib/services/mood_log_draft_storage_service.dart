import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodLogDraft {
  const MoodLogDraft({
    required this.selectedMood,
    required this.intensity,
    required this.notes,
    required this.tags,
  });

  final int selectedMood;
  final int intensity;
  final String notes;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'selectedMood': selectedMood,
    'intensity': intensity,
    'notes': notes,
    'tags': tags,
  };

  factory MoodLogDraft.fromJson(Map<String, dynamic> json) {
    return MoodLogDraft(
      selectedMood: (json['selectedMood'] as num?)?.toInt() ?? -1,
      intensity: ((json['intensity'] as num?)?.toInt() ?? 3).clamp(1, 5),
      notes: (json['notes'] as String? ?? '').trim(),
      tags: (json['tags'] as List? ?? const []).whereType<String>().toList(
        growable: false,
      ),
    );
  }

  bool get hasContent =>
      selectedMood != -1 ||
      intensity != 3 ||
      notes.isNotEmpty ||
      tags.isNotEmpty;
}

class MoodLogDraftStorageService {
  MoodLogDraftStorageService._();

  static final MoodLogDraftStorageService instance =
      MoodLogDraftStorageService._();

  static const _draftKeyBase = 'mood_log_draft_v4';

  String get _draftKey {
    final scopeKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${_draftKeyBase}_$scopeKey';
  }

  Future<MoodLogDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;

    return MoodLogDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(MoodLogDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
