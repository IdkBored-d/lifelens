class CommunityPromptService {
  CommunityPromptService._();

  static String dateKeyFor(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String promptForSphere(String sphereName, {DateTime? date}) {
    final selectedDate = date ?? DateTime.now();
    final prompts = _promptBank[sphereName.toLowerCase()] ?? _defaultPrompts;
    final normalized = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final index =
        normalized.difference(DateTime(2024, 1, 1)).inDays % prompts.length;
    return prompts[index];
  }

  static bool isCurrentPrompt({
    required String? storedPrompt,
    required String sphereName,
    required String? storedDateKey,
    DateTime? now,
  }) {
    final selectedDate = now ?? DateTime.now();
    final expectedDateKey = dateKeyFor(selectedDate);
    if (storedDateKey != expectedDateKey) {
      return false;
    }
    return storedPrompt == promptForSphere(sphereName, date: selectedDate);
  }

  static const Map<String, List<String>> _promptBank = {
    'mental health': [
      'Daily prompt: What helped you feel even slightly steadier today?',
      'Daily prompt: What thought or habit has been taking up too much space lately?',
      'Daily prompt: What is one small thing that made today feel lighter?',
      'Daily prompt: What support would make tonight or tomorrow easier?',
      'Daily prompt: What helped you come back to yourself this week?',
      'Daily prompt: What has been draining you more than you expected?',
      'Daily prompt: What is one gentle reset you want to repeat tomorrow?',
    ],
    'diabetes': [
      'Daily prompt: What meal, habit, or glucose pattern stood out today?',
      'Daily prompt: What small routine helped your numbers feel more manageable?',
      'Daily prompt: What snack, meal, or timing choice worked better than expected?',
      'Daily prompt: What do you wish someone had told you earlier about today’s challenge?',
      'Daily prompt: What helped you recover after a frustrating reading?',
      'Daily prompt: What simple swap or prep move made the day easier?',
      'Daily prompt: What pattern are you noticing that others here might relate to?',
    ],
    'sleep': [
      'Daily prompt: What changed your bedtime or wake-up quality recently?',
      'Daily prompt: What made it easier, or harder, to wind down tonight?',
      'Daily prompt: What part of your routine seems to affect sleep the most lately?',
      'Daily prompt: What is one thing you want to protect before bed tonight?',
      'Daily prompt: What has been helping your mornings feel less rough?',
      'Daily prompt: What bedtime habit keeps slipping, even when you mean well?',
      'Daily prompt: What sleep lesson from this week is worth sharing?',
    ],
    'exercise': [
      'Daily prompt: What movement felt doable today, even if it was small?',
      'Daily prompt: What helped you start moving when motivation was low?',
      'Daily prompt: What type of movement matched your energy best today?',
      'Daily prompt: What is one small win your body gave you this week?',
      'Daily prompt: What barrier keeps showing up before workouts or walks?',
      'Daily prompt: What routine tweak made movement easier to repeat?',
      'Daily prompt: What would make tomorrow’s movement feel more realistic?',
    ],
    'general': [
      'Daily prompt: Share one win, one challenge, and one next step.',
      'Daily prompt: What helped your day go a little better than expected?',
      'Daily prompt: What habit is worth keeping, and what are you ready to drop?',
      'Daily prompt: What felt heavy today, and what helped anyway?',
      'Daily prompt: What quick reset worked for you this week?',
      'Daily prompt: What are you trying again, but with less pressure this time?',
      'Daily prompt: What is one realistic goal you want support around today?',
    ],
  };

  static const List<String> _defaultPrompts = [
    'Daily prompt: Share one win, one challenge, and one next step.',
    'Daily prompt: What helped your day go a little better than expected?',
    'Daily prompt: What support would be most useful right now?',
    'Daily prompt: What realistic habit are you trying to keep this week?',
    'Daily prompt: What pattern are you starting to notice lately?',
    'Daily prompt: What felt harder than expected today?',
    'Daily prompt: What is one small thing you want to repeat tomorrow?',
  ];
}
