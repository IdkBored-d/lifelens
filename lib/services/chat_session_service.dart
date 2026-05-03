import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/chat_session.dart';
import '../database/chat_message.dart';
import '../database/isar_service.dart';

/// Manages MiniMe chat session lifecycle and persistence.
///
/// Each MiniMe screen visit is one session: from [startSession] (called in
/// initState) to [endSession] (called in dispose).
///
/// Write order: Write to ISAR (awaited) — source of truth.
///
/// Sessions with no [endTime] are repaired by [repairIncompleteSessions],
/// which should be called once at app startup.
class ChatSessionService {
  ChatSessionService();

  final IsarService _isar = IsarService.instance;

  // ── Session lifecycle ────────────────────────────────────────────────────────

  Future<String> startSession({
    required String moodLabel,
    required int    moodIntensity,
    String?         moodNotes,
  }) async {
    final sessionId = _uuid();
    final now       = DateTime.now();
    final session   = ChatSession()
      ..sessionId            = sessionId
      ..startTime            = now
      ..messageCount         = 0
      ..moodContextLabel     = moodLabel
      ..moodContextIntensity = moodIntensity
      ..moodContextNotes     = moodNotes
      ..wasInterrupted       = false
      ..createdAt            = now;
    await _isar.writeChatSession(session);
    return sessionId;
  }

  /// Persist a single message to ISAR. Write order rule: ISAR first, always.
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String text,
    required int    sequenceNumber,
  }) async {
    final now = DateTime.now();
    final msg = ChatMessage()
      ..sessionId      = sessionId
      ..role           = role
      ..text           = text
      ..timestamp      = now
      ..sequenceNumber = sequenceNumber;
    await _isar.writeChatMessage(msg);
  }

  /// Mark the session as cleanly ended. Fire-and-forget — dispose() must not block the UI.
  void endSession(String sessionId) {
    unawaited(_endSessionAsync(sessionId));
  }

  Future<void> _endSessionAsync(String sessionId) async {
    try {
      await _isar.endChatSession(sessionId, DateTime.now());
    } catch (e) {
      debugPrint('[ChatSession] endChatSession failed: $e');
    }
  }

  // ── Startup repair ───────────────────────────────────────────────────────────

  Future<void> repairIncompleteSessions() async {
    try {
      await _isar.markIncompleteChatSessions();
    } catch (e) {
      debugPrint('[ChatSession] repairIncompleteSessions failed (non-fatal): $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${now.toRadixString(16)}-${_rand4()}-${_rand4()}-${_rand4()}';
  }

  static String _rand4() =>
      (DateTime.now().microsecondsSinceEpoch & 0xFFFF).toRadixString(16).padLeft(4, '0');
}
