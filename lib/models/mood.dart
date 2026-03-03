class Mood {
  const Mood(this.emoji, this.label);

  final String emoji;
  final String label;
}

const moods = <Mood> [
  Mood('😊', 'Happy'),
  Mood('😌', 'Calm'),
  Mood('😐', 'Neutral'),
  Mood('😟', 'Anxious'),
  Mood('😞', 'Sad')
];