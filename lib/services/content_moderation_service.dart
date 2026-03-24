/// Content moderation service for community messages
class ContentModerationService {
  /// List of flagged words that may violate community guidelines
  static const List<String> _flaggedKeywords = [
    'spam',
    'abuse',
    'harmful',
    'violence',
    'hate',
  ];

  /// Check if content violates community guidelines
  static bool isFlaggedContent(String content) {
    final lowercaseContent = content.toLowerCase();
    
    for (final keyword in _flaggedKeywords) {
      if (lowercaseContent.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// Sanitize content by removing or masking flagged words
  static String sanitizeContent(String content) {
    String sanitized = content;
    
    for (final keyword in _flaggedKeywords) {
      final regex = RegExp(keyword, caseSensitive: false);
      sanitized = sanitized.replaceAll(regex, '*' * keyword.length);
    }
    
    return sanitized;
  }

  /// Get moderation status of content
  static ModerationStatus getModerationStatus(String content) {
    if (isFlaggedContent(content)) {
      return ModerationStatus.flagged;
    }
    return ModerationStatus.approved;
  }

  /// Check message for violations with detailed information
  static MessageCheckResult checkMessage(String text) {
    final detectedWords = <String>[];
    final lowercaseText = text.toLowerCase();
    
    for (final keyword in _flaggedKeywords) {
      if (lowercaseText.contains(keyword)) {
        detectedWords.add(keyword);
      }
    }
    
    return MessageCheckResult(
      isViolation: detectedWords.isNotEmpty,
      detectedWords: detectedWords,
    );
  }

  /// Get violation warning message based on warning count
  static String getViolationMessage(int warningCount) {
    switch (warningCount) {
      case 1:
        return 'This message contains community guideline violations. 1 warning issued.';
      case 2:
        return 'Multiple violations detected. 2 warnings issued. Please follow community guidelines.';
      case 3:
        return 'Repeated violations detected. 3 warnings issued. Further violations may result in suspension.';
      default:
        if (warningCount > 3) {
          return 'Your account is at risk of suspension due to repeated violations of community guidelines.';
        }
        return 'Message contains violations. Please review community guidelines.';
    }
  }
}

/// Result of message moderation check
class MessageCheckResult {
  final bool isViolation;
  final List<String> detectedWords;

  MessageCheckResult({
    required this.isViolation,
    required this.detectedWords,
  });
}

/// Moderation status for content
enum ModerationStatus {
  approved,
  flagged,
  rejected,
}
