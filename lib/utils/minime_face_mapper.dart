String miniMeFaceForMood(String? moodLabel) {
  switch (moodLabel) {
    case 'Happy':
      return '😊';
    case 'Calm':
      return '😌';
    case 'Anxious':
      return '😟';
    case 'Sad':
      return '😔';
    case 'Neutral':
    default:
      return '😐';
  }
}
