import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/shared_widgets/section_title.dart';
import 'package:lifelens/widgets/sleep_insights_widget.dart';
import 'package:lifelens/widgets/sleep_log_widget.dart';
import 'package:lifelens/widgets/sleep_tracking_widget.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  List<Sleep> sleepData = List.from(sampleSleepData);

  void _addSleepEntry(Sleep sleep) {
    setState(() {
      sleepData.insert(0, sleep);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sleep entry saved!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return Scaffold(
    appBar: AppBar(
      title: Text(
        'Sleep Tracking',
        style: theme.textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SleepTrackingWidget(onSleepLogged: _addSleepEntry),
            const SizedBox(height: 24),
            SleepInsightsWidget(sleepData: sleepData),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Recent Sleep'),
            const SizedBox(height: 12),
            SleepLogWidget(sleepData: sleepData),
          ],
        ),
      ),
    ),
  );
}
}