import 'package:isar/isar.dart';

part 'chat_message.g.dart';

/// ISAR collection for individual MiniMe chat messages.
/// Linked to a parent [ChatSession] via [sessionId].
/// Written by ChatSessionService BEFORE the quick-tracking file is updated.
@Collection()
class ChatMessage {
  Id id = Isar.autoIncrement;

  /// FK to [ChatSession.sessionId].
  @Index()
  late String sessionId;

  /// Either 'user' or 'assistant'.
  late String role;

  /// The full message text.
  late String text;

  /// When this message was sent / received.
  @Index()
  late DateTime timestamp;

  /// 0-based position within the session — used to restore display order.
  late int sequenceNumber;
}
