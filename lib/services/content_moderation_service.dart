class ContentModerationService {
  // List of prohibited words (profanity and slurs)
  // This is a basic list - you can expand it as needed
  static final Set<String> _prohibitedWords = {
    // Profanity
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'crap',
    'piss', 'cock', 'dick', 'pussy', 'cunt', 'whore', 'slut',

    // Racial slurs (partial list - add more as needed)
    'nigger', 'nigga', 'chink', 'spic', 'kike', 'wetback',
    'gook', 'raghead', 'towelhead', 'beaner',

    // Homophobic slurs
    'faggot', 'fag', 'dyke', 'tranny',

    // Ableist slurs
    'retard', 'retarded', 'spastic',
  };

  /// Check if the message contains any prohibited words
  static ModerationResult checkMessage(String message) {
    if (message.isEmpty) {
      return ModerationResult(isClean: true, detectedWords: []);
    }

    // Convert to lowercase for case-insensitive checking
    final lowerMessage = message.toLowerCase();

    // Remove punctuation and split into words
    final words = lowerMessage
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'));

    final detectedWords = <String>[];

    // Check each word against prohibited list
    for (final word in words) {
      if (_prohibitedWords.contains(word)) {
        detectedWords.add(word);
      }
    }

    // Also check for words embedded in the message (e.g., "f.u.c.k")
    for (final bannedWord in _prohibitedWords) {
      // Remove spaces, dots, and other separators to catch obfuscation
      final cleanedMessage = lowerMessage.replaceAll(RegExp(r'[\s\.\-_*]'), '');
      if (cleanedMessage.contains(bannedWord)) {
        if (!detectedWords.contains(bannedWord)) {
          detectedWords.add(bannedWord);
        }
      }
    }

    return ModerationResult(
      isClean: detectedWords.isEmpty,
      detectedWords: detectedWords,
    );
  }

  /// Get a user-friendly message about content violation
  static String getViolationMessage(int warningCount) {
    if (warningCount == 1) {
      return '⚠️ Warning 1/3: Your message contained inappropriate content and was not sent. Please keep conversations respectful.';
    } else if (warningCount == 2) {
      return '⚠️ Warning 2/3: Another inappropriate message detected. One more warning and you will be removed from this sphere.';
    } else if (warningCount >= 3) {
      return '🚫 Warning 3/3: You have been removed from this sphere for repeated violations of community guidelines.';
    }
    return '⚠️ Your message contained inappropriate content and was not sent.';
  }
}

/// Result of content moderation check
class ModerationResult {
  final bool isClean;
  final List<String> detectedWords;

  ModerationResult({required this.isClean, required this.detectedWords});

  bool get isViolation => !isClean;
}
