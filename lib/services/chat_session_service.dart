import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/chat_session.dart';
import '../database/chat_message.dart';
import '../database/isar_service.dart';
import 'quick_track_service.dart';
import 'template_summary_insight_service.dart';

/// Manages MiniMe chat session lifecycle and persistence.
///
/// Each MiniMe screen visit is one session: from [startSession] (called in
/// initState) to [endSession] (called in dispose).
///
/// Write order (matches the rest of the app):
///   1. Write to ISAR (awaited) — source of truth.
///   2. Regenerate conversation_summary.txt (unawaited) — quick-track file.
///
/// Sessions with no [endTime] are repaired by [repairIncompleteSessions],
/// which should be called once at app startup.
class ChatSessionService {
  ChatSessionService(this._quickTrack, this._templateInsight);

  final QuickTrackService             _quickTrack;
  final TemplateSummaryInsightService _templateInsight;
  final IsarService                   _isar = IsarService.instance;

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
  /// The conversation summary is regenerated when the session ends, not per message.
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

  /// Mark the session as cleanly ended, then regenerate the conversation
  /// quick-track summary. Fire-and-forget — dispose() must not block the UI.
  void endSession(String sessionId) {
    unawaited(_endSessionAsync(sessionId));
  }

  Future<void> _endSessionAsync(String sessionId) async {
    try {
      await _isar.endChatSession(sessionId, DateTime.now());
    } catch (e) {
      debugPrint('[ChatSession] endChatSession failed: $e');
    }
    await _generateAndWriteConversationSummary();
  }

  // ── Quick-track summary generation ──────────────────────────────────────────

  Future<void> _generateAndWriteConversationSummary() async {
    try {
      final sessions = await _isar.getChatSessionsForLastNDays(days: 14);
      final template = QuickTrackService.buildConversationTemplate(sessions);
      final insight  = _templateInsight.generateConversationInsight(template);
      final summary  = '$template\n\n$insight';
      await _quickTrack.writeConversationSummary(summary);
    } catch (e) {
      debugPrint('[ChatSession] Conversation summary write failed: $e');
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
