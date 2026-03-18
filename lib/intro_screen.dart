import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/health_service.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();

  int _index = 0;
  bool _saving = false;
  bool _importing = false;

  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _sleepController = TextEditingController();
  final _workoutController = TextEditingController();

  String _weightUnit = 'kg';
  String _heartRateUnit = 'bpm';

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heartRateController.dispose();
    _sleepController.dispose();
    _workoutController.dispose();
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

  Future<void> _importFromHealth() async {
    if (_importing) return;
    setState(() => _importing = true);

    try {
      final snapshot = await HealthService().fetchSnapshot();

      if (!mounted) return;

      if (snapshot.weight != null) {
        _weightController.text = snapshot.weight!.toStringAsFixed(1);
      }
      if (snapshot.heartRate != null) {
        _heartRateController.text = snapshot.heartRate!.toStringAsFixed(0);
      }
      if (snapshot.sleepHours != null) {
        _sleepController.text = snapshot.sleepHours!.toStringAsFixed(1);
      }
      if (snapshot.workoutSummary != null && snapshot.workoutSummary!.isNotEmpty) {
        _workoutController.text = snapshot.workoutSummary!;
      }

      if (snapshot.weightUnit != null && snapshot.weightUnit!.isNotEmpty) {
        _weightUnit = snapshot.weightUnit!;
      }
      if (snapshot.heartRateUnit != null && snapshot.heartRateUnit!.isNotEmpty) {
        _heartRateUnit = snapshot.heartRateUnit!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported available health data.')),
      );

      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import health data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final weight = double.tryParse(_weightController.text.trim());
    final heartRate = double.tryParse(_heartRateController.text.trim());
    final sleepHours = double.tryParse(_sleepController.text.trim());
    final workoutInfo = _workoutController.text.trim();

    if (weight == null || heartRate == null || sleepHours == null || workoutInfo.isEmpty) {
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboardingComplete': true,
        'healthSnapshot': {
          'source': 'manual_or_imported',
          'capturedAt': DateTime.now().toIso8601String(),
          'weight': weight,
          'weightUnit': _weightUnit,
          'heartRate': heartRate,
          'heartRateUnit': _heartRateUnit,
          'sleepHours': sleepHours,
          'sleepUnit': 'hours',
          'workoutSummary': workoutInfo,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
                : theme.colorScheme.outlineVariant.withOpacity(0.7),
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
                  Color.alphaBlend(cs.primary.withOpacity(0.10), cs.surface),
                  Color.alphaBlend(cs.secondary.withOpacity(0.08), cs.surface),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.spa_rounded, size: 18, color: cs.primary),
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
                          onImportPressed: _importing ? null : _importFromHealth,
                          onManualPressed: _importing
                              ? null
                              : () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOut,
                                  ),
                          importing: _importing,
                        ),
                        _HealthFormStep(
                          formKey: _formKey,
                          weightController: _weightController,
                          heartRateController: _heartRateController,
                          sleepController: _sleepController,
                          workoutController: _workoutController,
                          weightUnit: _weightUnit,
                          heartRateUnit: _heartRateUnit,
                          onWeightUnitChanged: (value) =>
                              setState(() => _weightUnit = value),
                          onHeartRateUnitChanged: (value) =>
                              setState(() => _heartRateUnit = value),
                        ),
                        _ReviewStep(
                          weight: _safeText(_weightController.text, '-'),
                          weightUnit: _weightUnit,
                          heartRate: _safeText(_heartRateController.text, '-'),
                          heartRateUnit: _heartRateUnit,
                          sleepHours: _safeText(_sleepController.text, '-'),
                          workoutInfo: _safeText(_workoutController.text, '-'),
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
  const _WelcomeStep({
    required this.onImportPressed,
    required this.onManualPressed,
    required this.importing,
  });

  final VoidCallback? onImportPressed;
  final VoidCallback? onManualPressed;
  final bool importing;

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
                Color.alphaBlend(cs.primary.withOpacity(0.55), cs.primaryContainer),
                Color.alphaBlend(cs.secondary.withOpacity(0.35), cs.primaryContainer),
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
                'We will ask for your heart rate, weight, sleep hours, and workout information to personalize your insights.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimaryContainer.withOpacity(0.9),
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
                FilledButton.icon(
                  onPressed: onImportPressed,
                  icon: importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: Text(
                    importing ? 'Importing from Health...' : 'Import from Apple Health/Health Connect',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onManualPressed,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Enter data manually'),
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
    required this.heartRateController,
    required this.sleepController,
    required this.workoutController,
    required this.weightUnit,
    required this.heartRateUnit,
    required this.onWeightUnitChanged,
    required this.onHeartRateUnitChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController weightController;
  final TextEditingController heartRateController;
  final TextEditingController sleepController;
  final TextEditingController workoutController;
  final String weightUnit;
  final String heartRateUnit;
  final ValueChanged<String> onWeightUnitChanged;
  final ValueChanged<String> onHeartRateUnitChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              TextFormField(
                controller: workoutController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Workout information',
                  hintText: 'Example: 4 workouts/week, 45 min each',
                  prefixIcon: const Icon(Icons.fitness_center_rounded),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Required';
                  if (v.length < 3) return 'Add a bit more detail';
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
    required this.heartRate,
    required this.heartRateUnit,
    required this.sleepHours,
    required this.workoutInfo,
  });

  final String weight;
  final String weightUnit;
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
          color: cs.surfaceContainerHighest.withOpacity(0.7),
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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            row('Weight', '$weight $weightUnit'),
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