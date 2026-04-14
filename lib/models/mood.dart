class Mood {
  const Mood(this.emoji, this.label);

  final String emoji;
  final String label;
}

const moods = <Mood> [
  Mood('😐', 'Neutral'),
  Mood('😠', 'Angry'),
  Mood('😨', 'Scared'),
  Mood('😊', 'Happy'),
  Mood('🥰', 'Affectionate'),
  Mood('😔', 'Sad'),
  Mood('😲', 'Surprised'),
];
