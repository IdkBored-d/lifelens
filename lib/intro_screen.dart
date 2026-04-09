import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/fitness_entry.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();

  int _index = 0;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _sleepController = TextEditingController();

  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  String _heartRateUnit = 'bpm';
  String? _selectedWorkoutFrequency;

  static const List<String> _workoutFrequencyOptions = [
    'Rarely or never',
    '1-2 times per week',
    '3-4 times per week',
    '5-6 times per week',
    'Daily',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _heartRateController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_index == 1) {
      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid) return;
    }

    if (_index < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _previousPage() async {
    if (_index > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final heartRate = double.tryParse(_heartRateController.text.trim());
    final sleepHours = double.tryParse(_sleepController.text.trim());
    final workoutInfo = _selectedWorkoutFrequency;

    if (weight == null ||
        height == null ||
        heartRate == null ||
        sleepHours == null ||
        workoutInfo == null ||
        workoutInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Mark onboarding complete in Firestore — AppRoot navigation depends on this.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Write health snapshot to ISAR (source of truth for health data).
      const activityMap = {
        'Rarely or never':    0.0,
        '1-2 times per week': 0.25,
        '3-4 times per week': 0.5,
        '5-6 times per week': 0.75,
        'Daily':              1.0,
      };
      final weightKg      = (_weightUnit == 'lb') ? weight * 0.453592 : weight;
      final heightM       = (_heightUnit == 'in') ? height * 0.0254 : height / 100.0;
      final bmi           = weightKg / (heightM * heightM);
      final activityIndex = activityMap[workoutInfo] ?? 0.25;
      final now           = DateTime.now();
      final snapshot      = FitnessEntry()
        ..date                 = now.toIso8601String().split('T').first
        ..fitnessScore         = 0.0
        ..fitProbability       = 0.0
        ..isFit                = false
        ..confidenceOk         = false
        ..dataFreshnessFlagged = true
        ..isOnboardingSnapshot = true
        ..age                  = 0.0
        ..bmi                  = bmi
        ..heartRate            = heartRate
        ..sleepHours           = sleepHours
        ..smokes               = false
        ..nutritionQuality     = 0.5
        ..activityIndex        = activityIndex
        ..isMale               = false
        ..healthDataTimestamp  = now
        ..inferenceTimestamp   = now;
      await AppServices.isar.writeFitnessEntry(snapshot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to finish onboarding: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _safeText(String text, String fallback) {
    final value = text.trim();
    if (value.isEmpty) return fallback;
    return value;
  }

  Widget _buildProgressDots(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha:0.7),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface,
                  Color.alphaBlend(cs.primary.withValues(alpha:0.10), cs.surface),
                  Color.alphaBlend(cs.secondary.withValues(alpha:0.08), cs.surface),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha:0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha:0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.spa_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LifeLens Onboarding',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_index > 0)
                        TextButton(
                          onPressed: _saving ? null : _previousPage,
                          child: const Text('Back'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildProgressDots(theme),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (value) => setState(() => _index = value),
                      children: [
                        _WelcomeStep(
                          onContinuePressed: () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                        ),
                        _HealthFormStep(
                          formKey: _formKey,
                          weightController: _weightController,
                          heightController: _heightController,
                          heartRateController: _heartRateController,
                          sleepController: _sleepController,
                          workoutFrequencyOptions: _workoutFrequencyOptions,
                          selectedWorkoutFrequency: _selectedWorkoutFrequency,
                          onWorkoutFrequencyChanged: (value) {
                            setState(() => _selectedWorkoutFrequency = value);
                          },
                          weightUnit: _weightUnit,
                          heightUnit: _heightUnit,
                          heartRateUnit: _heartRateUnit,
                          onWeightUnitChanged: (value) =>
                              setState(() => _weightUnit = value),
                          onHeightUnitChanged: (value) =>
                              setState(() => _heightUnit = value),
                          onHeartRateUnitChanged: (value) =>
                              setState(() => _heartRateUnit = value),
                        ),
                        _ReviewStep(
                          weight: _safeText(_weightController.text, '-'),
                          weightUnit: _weightUnit,
                          height: _safeText(_heightController.text, '-'),
                          heightUnit: _heightUnit,
                          heartRate: _safeText(_heartRateController.text, '-'),
                          heartRateUnit: _heartRateUnit,
                          sleepHours: _safeText(_sleepController.text, '-'),
                          workoutInfo: _selectedWorkoutFrequency ?? '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _nextPage,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : _index == 2
                            ? 'Finish onboarding'
                            : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinuePressed});

  final VoidCallback onContinuePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  cs.primary.withValues(alpha:0.55),
                  cs.primaryContainer,
                ),
                Color.alphaBlend(
                  cs.secondary.withValues(alpha:0.35),
                  cs.primaryContainer,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let\'s set up your health baseline',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We will ask for your heart rate, weight, sleep hours, and workout frequency to personalize your insights.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimaryContainer.withValues(alpha:0.9),
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onContinuePressed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Start setup'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthFormStep extends StatelessWidget {
  const _HealthFormStep({
    required this.formKey,
    required this.weightController,
    required this.heightController,
    required this.heartRateController,
    required this.sleepController,
    required this.workoutFrequencyOptions,
    required this.selectedWorkoutFrequency,
    required this.onWorkoutFrequencyChanged,
    required this.weightUnit,
    required this.heightUnit,
    required this.heartRateUnit,
    required this.onWeightUnitChanged,
    required this.onHeightUnitChanged,
    required this.onHeartRateUnitChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController heartRateController;
  final TextEditingController sleepController;
  final List<String> workoutFrequencyOptions;
  final String? selectedWorkoutFrequency;
  final ValueChanged<String?> onWorkoutFrequencyChanged;
  final String weightUnit;
  final String heightUnit;
  final String heartRateUnit;
  final ValueChanged<String> onWeightUnitChanged;
  final ValueChanged<String> onHeightUnitChanged;
  final ValueChanged<String> onHeartRateUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Form(
          key: formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Text(
                'Required health information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        hintText: '170',
                        prefixIcon: Icon(Icons.height_rounded),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid number';
                        if (parsed <= 0 || parsed > 300) return 'Check value';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: heightUnit,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                    ],
                    onChanged: (value) {
                      if (value != null) onHeightUnitChanged(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        hintText: '70.5',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: weightUnit,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'lb', child: Text('lb')),
                    ],
                    onChanged: (value) {
                      if (value != null) onWeightUnitChanged(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: heartRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Resting heart rate',
                        hintText: '62',
                        prefixIcon: Icon(Icons.favorite_border_rounded),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid number';
                        if (parsed < 20 || parsed > 220) return 'Check value';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: heartRateUnit,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'bpm', child: Text('bpm')),
                    ],
                    onChanged: (value) {
                      if (value != null) onHeartRateUnitChanged(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sleepController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Average sleep hours',
                  hintText: '7.5',
                  prefixIcon: Icon(Icons.bedtime_outlined),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Required';
                  final parsed = double.tryParse(v);
                  if (parsed == null) return 'Invalid number';
                  if (parsed < 0 || parsed > 24) return 'Enter 0-24';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedWorkoutFrequency,
                decoration: const InputDecoration(
                  labelText: 'Workout frequency',
                  prefixIcon: Icon(Icons.fitness_center_rounded),
                ),
                items: workoutFrequencyOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: onWorkoutFrequencyChanged,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.weight,
    required this.weightUnit,
    required this.height,
    required this.heightUnit,
    required this.heartRate,
    required this.heartRateUnit,
    required this.sleepHours,
    required this.workoutInfo,
  });

  final String weight;
  final String weightUnit;
  final String height;
  final String heightUnit;
  final String heartRate;
  final String heartRateUnit;
  final String sleepHours;
  final String workoutInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(String label, String value) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha:0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Review your baseline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            row('Weight', '$weight $weightUnit'),
            row('Height', '$height $heightUnit'),
            row('Heart rate', '$heartRate $heartRateUnit'),
            row('Sleep', '$sleepHours hours'),
            row('Workout', workoutInfo),
            const SizedBox(height: 4),
            Text(
              'Tap Finish onboarding to save this data and continue.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
