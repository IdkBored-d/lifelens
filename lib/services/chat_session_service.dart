import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/chat_session.dart';
import '../database/chat_message.dart';
import '../database/isar_service.dart';
import 'quick_track_service.dart';

/// Manages MiniMe chat session lifecycle and persistence.
///
/// Each MiniMe screen visit is one session: from [startSession] (called in
/// initState) to [endSession] (called in dispose).
///
/// Write order (matches the rest of the app):
///   1. Write to ISAR (awaited) — source of truth.
///   2. Append to conversations.json (unawaited) — quick-track file.
///
/// Sessions with no [endTime] are repaired by [repairIncompleteSessions],
/// which should be called once at app startup.
class ChatSessionService {
  ChatSessionService(this._quickTrack);

  final QuickTrackService _quickTrack;
  final IsarService _isar = IsarService.instance;

  // ── Session lifecycle ────────────────────────────────────────────────────────

  /// Create a new session and persist it to ISAR.
  /// Returns the session ID (UUID v4) that callers must hold onto.
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

  /// Persist a single message to ISAR, then fire-and-forget to the quick-track
  /// file following the standard write-order rule.
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

    unawaited(
      _quickTrack.appendChatEntry(ChatLogEntry(
        sessionId: sessionId,
        role:      role,
        text:      text,
        timestamp: now.toIso8601String(),
      )).catchError(
        (Object e) => debugPrint('[ChatSession] QuickTrack write failed: $e'),
      ),
    );
  }

  /// Mark the session as cleanly ended. Fire-and-forget — dispose() must not
  /// block the UI tear-down.
  void endSession(String sessionId) {
    unawaited(
      _isar.endChatSession(sessionId, DateTime.now()).catchError(
        (Object e) => debugPrint('[ChatSession] endSession failed: $e'),
      ),
    );
  }

  // ── Startup repair ───────────────────────────────────────────────────────────

  /// Find sessions that have no endTime (app was killed mid-chat) and mark
  /// them as interrupted. Called once at app startup before screens load.
  Future<void> repairIncompleteSessions() async {
    try {
      await _isar.markIncompleteChatSessions();
    } catch (e) {
      debugPrint('[ChatSession] repairIncompleteSessions failed (non-fatal): $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Simple time-based UUID v4 substitute.
  /// Good enough for a local session ID — collisions are astronomically unlikely.
  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${now.toRadixString(16)}-${_rand4()}-${_rand4()}-${_rand4()}';
  }

  static String _rand4() =>
      (DateTime.now().microsecondsSinceEpoch & 0xFFFF).toRadixString(16).padLeft(4, '0');
}
