import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/sleep_store.dart';
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
  final SleepStore _sleepStore = SleepStore();
  List<Sleep> sleepData = const <Sleep>[];

  @override
  void initState() {
    super.initState();
    _sleepStore.addListener(_syncSleepData);
    sleepData = _sleepStore.items;
    _sleepStore.refresh();
  }

  @override
  void dispose() {
    _sleepStore.removeListener(_syncSleepData);
    _sleepStore.dispose();
    super.dispose();
  }

  void _syncSleepData() {
    if (!mounted) return;
    setState(() {
      sleepData = _sleepStore.items;
    });
  }

  Future<String?> _addSleepEntry(Sleep sleep) async {
    final message = await _sleepStore.add(sleep);
    if (!mounted) return message;

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
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
