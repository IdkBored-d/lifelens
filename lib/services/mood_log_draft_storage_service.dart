import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MoodLogDraft {
  const MoodLogDraft({
    required this.selectedMood,
    required this.notes,
    required this.tags,
  });

  final int selectedMood;
  final String notes;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'selectedMood': selectedMood,
    'notes': notes,
    'tags': tags,
  };

  factory MoodLogDraft.fromJson(Map<String, dynamic> json) {
    return MoodLogDraft(
      selectedMood: (json['selectedMood'] as num?)?.toInt() ?? -1,
      notes: (json['notes'] as String? ?? '').trim(),
      tags: (json['tags'] as List? ?? const []).whereType<String>().toList(
        growable: false,
      ),
    );
  }

  bool get hasContent =>
      selectedMood != -1 ||
      notes.isNotEmpty ||
      tags.isNotEmpty;
}

class MoodLogDraftStorageService {
  MoodLogDraftStorageService._();

  static final MoodLogDraftStorageService instance =
      MoodLogDraftStorageService._();

  static const _draftKey = 'mood_log_draft_v3';

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
