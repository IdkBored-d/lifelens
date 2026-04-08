import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MiniMeStoredMessage {
  const MiniMeStoredMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  factory MiniMeStoredMessage.fromJson(Map<String, dynamic> json) {
    return MiniMeStoredMessage(
      role: (json['role'] as String? ?? 'assistant').trim(),
      text: (json['text'] as String? ?? '').trim(),
    );
  }
}

class MiniMeChatStorageService {
  MiniMeChatStorageService._();

  static final MiniMeChatStorageService instance = MiniMeChatStorageService._();

  static const _chatKey = 'mini_me_chat_history_v1';

  Future<List<MiniMeStoredMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_chatKey) ?? const [];

    return raw
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .map(MiniMeStoredMessage.fromJson)
        .where((item) => item.text.isNotEmpty)
        .toList();
  }

  Future<void> saveMessages(List<MiniMeStoredMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = messages
        .map((item) => jsonEncode(item.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_chatKey, encoded);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatKey);
  }
}
