class ExerciseDemoContent {
  const ExerciseDemoContent({
    required this.description,
    required this.demoSteps,
    required this.formTips,
    this.equipment = 'Bodyweight',
  });

  final String description;
  final List<String> demoSteps;
  final List<String> formTips;
  final String equipment;
}

ExerciseDemoContent resolveExerciseDemoContent({
  required String name,
  required String muscle,
  required String type,
  String? description,
  List<String>? demoSteps,
  List<String>? formTips,
  String? equipment,
}) {
  if ((description?.trim().isNotEmpty ?? false) &&
      (demoSteps?.isNotEmpty ?? false) &&
      (formTips?.isNotEmpty ?? false)) {
    return ExerciseDemoContent(
      description: description!.trim(),
      demoSteps: demoSteps!,
      formTips: formTips!,
      equipment: (equipment == null || equipment.trim().isEmpty)
          ? 'Bodyweight'
          : equipment.trim(),
    );
  }

  final normalizedName = name.toLowerCase();
  final normalizedMuscle = muscle.toLowerCase();
  final normalizedType = type.toLowerCase();

  if (normalizedName.contains('squat')) {
    return const ExerciseDemoContent(
      description:
          'A lower-body staple that builds leg strength, hip mobility, and core control.',
      equipment: 'Bodyweight or dumbbells',
      demoSteps: [
        'Stand with feet about shoulder-width apart and brace your core.',
        'Push hips back and bend knees while keeping your chest lifted.',
        'Lower until thighs are parallel to the floor, then drive through your heels to stand.',
      ],
      formTips: [
        'Keep knees tracking over toes throughout each rep.',
        'Maintain a neutral spine and avoid collapsing your chest.',
      ],
    );
  }

  if (normalizedName.contains('push')) {
    return const ExerciseDemoContent(
      description:
          'An upper-body press that trains chest, shoulders, triceps, and full-body tension.',
      equipment: 'Bodyweight',
      demoSteps: [
        'Start in a high plank with hands slightly wider than shoulders.',
        'Lower your body in one line until your chest is near the floor.',
        'Press back up while keeping glutes and core engaged.',
      ],
      formTips: [
        'Avoid flaring elbows too wide; aim roughly 45 degrees from torso.',
        'Keep neck neutral and do not let hips sag.',
      ],
    );
  }

  if (normalizedName.contains('plank')) {
    return const ExerciseDemoContent(
      description:
          'An isometric core exercise that improves trunk stability and posture control.',
      equipment: 'Bodyweight',
      demoSteps: [
        'Set forearms on the floor with elbows under shoulders.',
        'Step feet back and align shoulders, hips, and ankles.',
        'Hold while breathing steadily and keeping your core tight.',
      ],
      formTips: [
        'Think about pulling ribs down to avoid low-back arching.',
        'Start with shorter holds and increase duration gradually.',
      ],
    );
  }

  if (normalizedType == 'cardio') {
    return const ExerciseDemoContent(
      description:
          'A cardio-focused movement to improve heart health, stamina, and energy levels.',
      equipment: 'Bodyweight',
      demoSteps: [
        'Start with a 3-5 minute warm-up at an easy pace.',
        'Build to a moderate intensity where talking is possible but effortful.',
        'Finish with a short cool-down and relaxed breathing.',
      ],
      formTips: [
        'Use a pace you can sustain with good technique.',
        'Prioritize consistency over intensity in early weeks.',
      ],
    );
  }

  if (normalizedType == 'mobility' || normalizedName.contains('stretch')) {
    return const ExerciseDemoContent(
      description:
          'A mobility movement designed to improve range of motion and reduce stiffness.',
      equipment: 'Mat (optional)',
      demoSteps: [
        'Move slowly into a comfortable range without forcing position.',
        'Pause briefly at end range while maintaining smooth breathing.',
        'Return to start under control and repeat for quality reps.',
      ],
      formTips: [
        'You should feel gentle tension, not sharp pain.',
        'Control every rep; avoid bouncing through the stretch.',
      ],
    );
  }

  if (normalizedMuscle == 'core') {
    return const ExerciseDemoContent(
      description:
          'A core-strength movement to improve trunk stability and movement efficiency.',
      equipment: 'Bodyweight',
      demoSteps: [
        'Set your posture and gently brace your core before starting.',
        'Perform each rep with slow, controlled motion and steady breathing.',
        'Stop each set before form breaks down.',
      ],
      formTips: [
        'Keep lower back neutral throughout the movement.',
        'Use tempo control to increase challenge safely.',
      ],
    );
  }

  return const ExerciseDemoContent(
    description:
        'A balanced exercise for strength and conditioning. Use controlled reps and consistent form.',
    equipment: 'Bodyweight or light equipment',
    demoSteps: [
      'Set up your stance and align posture before each set.',
      'Move through a full, controlled range of motion.',
      'Rest briefly, then repeat while maintaining clean technique.',
    ],
    formTips: [
      'Prioritize form quality over speed or load.',
      'Track reps and effort to progress week to week.',
    ],
  );
}
