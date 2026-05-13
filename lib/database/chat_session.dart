import 'package:isar_community/isar.dart';

part 'chat_session.g.dart';

/// ISAR collection for MiniMe chat sessions.
/// A session spans from when the user sends their first message to when they
/// navigate away from the MiniMe screen. Each visit creates a new session.
/// Sessions with a null [endTime] were interrupted (crash / force-quit).
@Collection()
class ChatSession {
  Id id = Isar.autoIncrement;

  /// Unique session identifier (UUID v4).
  @Index(unique: true)
  late String sessionId;

  /// When the user entered the MiniMe screen and sent their first message.
  late DateTime startTime;

  /// When the user navigated away. Null if the session was interrupted.
  DateTime? endTime;

  /// Total number of messages in this session (user + assistant combined).
  late int messageCount;

  /// Mood label at the start of the session (e.g. "joy", "anxious").
  late String moodContextLabel;

  /// Mood intensity at session start (0–5 scale).
  late int moodContextIntensity;

  /// Optional mood notes at session start.
  String? moodContextNotes;

  /// Whether the session ended abnormally (crash / force-quit).
  /// Set to true by [IsarService.markIncompleteChatSessions] on next launch.
  late bool wasInterrupted;

  @Index()
  late DateTime createdAt;
}
