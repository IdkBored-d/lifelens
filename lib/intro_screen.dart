import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'package:lifelens/onboarding_screen.dart';
import 'package:lifelens/services/health_service.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();

  int _index = 0;
  bool _saving = false;
  bool _importingHealth = false;
  String? _healthImportMessage;
  HealthSnapshot? _importedHealthSnapshot;

  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _sleepController = TextEditingController();

  String _weightUnit = 'kg';
  String _heightUnit = 'in';
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
    final sleepHours = double.tryParse(_sleepController.text.trim());
    final workoutInfo = _selectedWorkoutFrequency;

    if (weight == null ||
        height == null ||
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
        'Rarely or never': 0.0,
        '1-2 times per week': 0.25,
        '3-4 times per week': 0.5,
        '5-6 times per week': 0.75,
        'Daily': 1.0,
      };
      final weightKg = (_weightUnit == 'lb') ? weight * 0.453592 : weight;
      final heightM = (_heightUnit == 'in') ? height * 0.0254 : height / 100.0;
      final bmi = weightKg / (heightM * heightM);
      final activityIndex = activityMap[workoutInfo] ?? 0.25;
      final now = DateTime.now();
      final snapshot = FitnessEntry()
        ..date = now.toIso8601String().split('T').first
        ..fitnessScore = 0.0
        ..fitProbability = 0.0
        ..isFit = false
        ..confidenceOk = false
        ..dataFreshnessFlagged = true
        ..isOnboardingSnapshot = true
        ..age = 0.0
        ..bmi = bmi
        ..heartRate = 0.0
        ..sleepHours = sleepHours
        ..smokes = false
        ..nutritionQuality = 0.5
        ..activityIndex = activityIndex
        ..isMale = false
        ..healthDataTimestamp = _importedHealthSnapshot?.capturedAt ?? now
        ..inferenceTimestamp = now;
      await AppServices.isar.writeFitnessEntry(snapshot);

      if (_importedHealthSnapshot != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'onboardingHealthImport': _importedHealthSnapshot!.toFirestore(),
        }, SetOptions(merge: true));
      }
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

  Future<void> _importFromAppleHealth() async {
    if (_importingHealth) return;

    setState(() {
      _importingHealth = true;
      _healthImportMessage = null;
    });

    try {
      final snapshot = await HealthService().fetchSnapshot();
      if (!mounted) return;

      _applyImportedHealthSnapshot(snapshot);
      setState(() {
        _importedHealthSnapshot = snapshot;
        _healthImportMessage = 'Imported data from ${snapshot.source}.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _healthImportMessage =
            'Apple Health took too long to respond. Please return to LifeLens and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthImportMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _importingHealth = false);
      }
    }
  }

  void _applyImportedHealthSnapshot(HealthSnapshot snapshot) {
    if (snapshot.weight != null) {
      if ((snapshot.weightUnit ?? '').toLowerCase().contains('lb')) {
        _weightUnit = 'lb';
        _weightController.text = snapshot.weight!.toStringAsFixed(1);
      } else {
        _weightUnit = 'kg';
        _weightController.text = snapshot.weight!.toStringAsFixed(1);
      }
    }

    if (snapshot.height != null) {
      final unit = (snapshot.heightUnit ?? '').toLowerCase();
      if (unit.contains('m')) {
        _heightUnit = 'cm';
        _heightController.text = (snapshot.height! * 100).round().toString();
      } else if (unit.contains('cm')) {
        _heightUnit = 'cm';
        _heightController.text = snapshot.height!.round().toString();
      }
    }

    if (snapshot.sleepHours != null) {
      _sleepController.text = snapshot.sleepHours!.toStringAsFixed(1);
    }

    final workoutCount = snapshot.workoutCount14d ?? 0;
    if (workoutCount > 0) {
      _selectedWorkoutFrequency = _mapWorkoutCountToFrequency(workoutCount);
    }
  }

  String _mapWorkoutCountToFrequency(int count14d) {
    if (count14d >= 12) return 'Daily';
    if (count14d >= 8) return '5-6 times per week';
    if (count14d >= 5) return '3-4 times per week';
    if (count14d >= 2) return '1-2 times per week';
    return 'Rarely or never';
  }

  String _safeText(String text, String fallback) {
    final value = text.trim();
    if (value.isEmpty) return fallback;
    return value;
  }

  String _heightDisplayText() {
    final raw = _heightController.text.trim();
    if (raw.isEmpty) return '-';

    final height = double.tryParse(raw);
    if (height == null) return raw;

    if (_heightUnit == 'in') {
      final totalInches = height.round();
      final feet = totalInches ~/ 12;
      final inches = totalInches % 12;
      return '$feet\'$inches"';
    }

    return '${height.round()} cm';
  }

  Future<void> _pickHeight() async {
    final initialHeight =
        double.tryParse(_heightController.text.trim()) ??
        (_heightUnit == 'in' ? 69.0 : 170.0);

    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _HeightPickerSheet(
          unit: _heightUnit,
          initialHeight: initialHeight,
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _heightController.text = _heightUnit == 'in'
          ? selected.round().toString()
          : selected.toStringAsFixed(0);
    });
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
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
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
                  Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.10),
                    cs.surface,
                  ),
                  Color.alphaBlend(
                    cs.secondary.withValues(alpha: 0.08),
                    cs.surface,
                  ),
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
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.6),
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
                          sleepController: _sleepController,
                          workoutFrequencyOptions: _workoutFrequencyOptions,
                          selectedWorkoutFrequency: _selectedWorkoutFrequency,
                          onWorkoutFrequencyChanged: (value) {
                            setState(() => _selectedWorkoutFrequency = value);
                          },
                          weightUnit: _weightUnit,
                          heightUnit: _heightUnit,
                          heightDisplayValue: _heightDisplayText(),
                          onWeightUnitChanged: (value) =>
                              setState(() => _weightUnit = value),
                          onHeightUnitChanged: (value) {
                            setState(() {
                              _heightUnit = value;
                              _heightController.clear();
                            });
                          },
                          onHeightPressed: _pickHeight,
                          showAppleHealthImport:
                              !kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS,
                          isImportingHealth: _importingHealth,
                          healthImportMessage: _healthImportMessage,
                          importedSource: _importedHealthSnapshot?.source,
                          onImportAppleHealth: _importFromAppleHealth,
                        ),
                        _ReviewStep(
                          weight: _safeText(_weightController.text, '-'),
                          weightUnit: _weightUnit,
                          height: _heightDisplayText(),
                          heightUnit: _heightUnit,
                          sleepHours: _safeText(_sleepController.text, '-'),
                          workoutInfo: _selectedWorkoutFrequency ?? '-',
                          importedSource: _importedHealthSnapshot?.source,
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        OnboardingScreen(
          onGetStarted: onContinuePressed,
          ctaLabel: 'Start setup',
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
    required this.sleepController,
    required this.workoutFrequencyOptions,
    required this.selectedWorkoutFrequency,
    required this.onWorkoutFrequencyChanged,
    required this.weightUnit,
    required this.heightUnit,
    required this.heightDisplayValue,
    required this.onWeightUnitChanged,
    required this.onHeightUnitChanged,
    required this.onHeightPressed,
    required this.showAppleHealthImport,
    required this.isImportingHealth,
    required this.healthImportMessage,
    required this.importedSource,
    required this.onImportAppleHealth,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController sleepController;
  final List<String> workoutFrequencyOptions;
  final String? selectedWorkoutFrequency;
  final ValueChanged<String?> onWorkoutFrequencyChanged;
  final String weightUnit;
  final String heightUnit;
  final String heightDisplayValue;
  final ValueChanged<String> onWeightUnitChanged;
  final ValueChanged<String> onHeightUnitChanged;
  final Future<void> Function() onHeightPressed;
  final bool showAppleHealthImport;
  final bool isImportingHealth;
  final String? healthImportMessage;
  final String? importedSource;
  final Future<void> Function() onImportAppleHealth;

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
              if (showAppleHealthImport) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              importedSource == null
                                  ? 'Import from Apple Health'
                                  : 'Imported from $importedSource',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: isImportingHealth
                                ? null
                                : onImportAppleHealth,
                            child: Text(
                              isImportingHealth ? 'Importing...' : 'Import',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This can fill in your weight, height, sleep, and workout activity automatically.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if ((healthImportMessage ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          healthImportMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FormField<String>(
                      initialValue: heightController.text,
                      validator: (_) {
                        final v = heightController.text.trim();
                        if (v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid number';
                        if (heightUnit == 'in' &&
                            (parsed < 36 || parsed > 96)) {
                          return 'Check value';
                        }
                        if (heightUnit == 'cm' &&
                            (parsed < 90 || parsed > 250)) {
                          return 'Check value';
                        }
                        return null;
                      },
                      builder: (field) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await onHeightPressed();
                            field.didChange(heightController.text);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Height',
                              hintText: heightUnit == 'in' ? '5\'9"' : '170 cm',
                              prefixIcon: const Icon(Icons.height_rounded),
                              suffixIcon: const Icon(Icons.unfold_more_rounded),
                              errorText: field.errorText,
                            ),
                            child: Text(
                              heightDisplayValue == '-'
                                  ? 'Scroll to select'
                                  : heightDisplayValue,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: heightDisplayValue == '-'
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                            ),
                          ),
                        );
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
              if (heightDisplayValue != '-')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Selected: $heightDisplayValue',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
    required this.sleepHours,
    required this.workoutInfo,
    required this.importedSource,
  });

  final String weight;
  final String weightUnit;
  final String height;
  final String heightUnit;
  final String sleepHours;
  final String workoutInfo;
  final String? importedSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(String label, String value) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
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
            row('Height', height),
            row('Sleep', '$sleepHours hours'),
            row('Workout', workoutInfo),
            if (importedSource != null) row('Imported from', importedSource!),
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

class _HeightPickerSheet extends StatefulWidget {
  const _HeightPickerSheet({required this.unit, required this.initialHeight});

  final String unit;
  final double initialHeight;

  @override
  State<_HeightPickerSheet> createState() => _HeightPickerSheetState();
}

class _HeightPickerSheetState extends State<_HeightPickerSheet> {
  late int _selectedFeet;
  late int _selectedInches;
  late int _selectedCentimeters;

  @override
  void initState() {
    super.initState();
    if (widget.unit == 'in') {
      final totalInches = widget.initialHeight.round().clamp(36, 96);
      _selectedFeet = totalInches ~/ 12;
      _selectedInches = totalInches % 12;
      _selectedCentimeters = 170;
    } else {
      _selectedCentimeters = widget.initialHeight.round().clamp(90, 250);
      _selectedFeet = 5;
      _selectedInches = 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your height',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.unit == 'in'
                    ? 'Scroll to a height like 5\'9".'
                    : 'Scroll to your height in centimeters.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: widget.unit == 'in'
                    ? Row(
                        children: [
                          Expanded(
                            child: _NumberWheel(
                              min: 3,
                              max: 8,
                              initialValue: _selectedFeet,
                              labelBuilder: (value) => '$value ft',
                              onChanged: (value) =>
                                  setState(() => _selectedFeet = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberWheel(
                              min: 0,
                              max: 11,
                              initialValue: _selectedInches,
                              labelBuilder: (value) => '$value in',
                              onChanged: (value) =>
                                  setState(() => _selectedInches = value),
                            ),
                          ),
                        ],
                      )
                    : _NumberWheel(
                        min: 90,
                        max: 250,
                        initialValue: _selectedCentimeters,
                        labelBuilder: (value) => '$value cm',
                        onChanged: (value) =>
                            setState(() => _selectedCentimeters = value),
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final result = widget.unit == 'in'
                      ? (_selectedFeet * 12 + _selectedInches).toDouble()
                      : _selectedCentimeters.toDouble();
                  Navigator.of(context).pop(result);
                },
                child: const Text('Use this height'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberWheel extends StatelessWidget {
  const _NumberWheel({
    required this.min,
    required this.max,
    required this.initialValue,
    required this.labelBuilder,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int initialValue;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = List<int>.generate(max - min + 1, (index) => min + index);
    final initialIndex = (initialValue - min).clamp(0, values.length - 1);

    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: initialIndex),
      itemExtent: 48,
      diameterRatio: 1.3,
      perspective: 0.004,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) => onChanged(values[index]),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: values.length,
        builder: (context, index) {
          final value = values[index];
          return Center(
            child: Text(
              labelBuilder(value),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}
