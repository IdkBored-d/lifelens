String miniMeFaceForMood(String? moodLabel) {
  switch ((moodLabel ?? '').trim().toLowerCase()) {
    case 'happy':
    case 'joy':
      return '😊';
    case 'affectionate':
    case 'love':
      return '🥰';
    case 'angry':
    case 'anger':
      return '😠';
    case 'scared':
    case 'fear':
    case 'anxious':
      return '😨';
    case 'surprised':
    case 'surprise':
      return '😲';
    case 'sad':
    case 'sadness':
      return '😔';
    case 'neutral':
    case 'content':
    default:
      return '😐';
  }
}
