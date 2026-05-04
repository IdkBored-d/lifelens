import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:lifelens/shared_widgets/section_title.dart';
import 'package:lifelens/widgets/sleep_log_widget.dart';
import 'package:lifelens/widgets/sleep_tracking_widget.dart';
import 'package:provider/provider.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SleepScreenState extends State<SleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SleepStore>().refresh();
    });
  }

  Future<String?> _addSleepEntry(Sleep sleep) async {
    final message = await context.read<SleepStore>().add(sleep);
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
    final canPop = Navigator.canPop(context);
    final sleepSelection = context.select<SleepStore, _SleepScreenSelection>(
      (sleepStore) => _SleepScreenSelection.fromItems(sleepStore.items),
    );

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Sleep Log'),
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
              const SectionTitle(title: 'Recent Sleep'),
              const SizedBox(height: 12),
              SleepLogWidget(sleepData: sleepSelection.items),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepScreenSelection {
  const _SleepScreenSelection({required this.items, required this.signature});

  factory _SleepScreenSelection.fromItems(List<Sleep> items) {
    final today = DateTime.now();
    final visibleItems = items
        .where((item) => _isSameDay(item.date, today))
        .take(20)
        .toList(growable: false);
    final signature = visibleItems
        .map(
          (item) =>
              '${item.date.microsecondsSinceEpoch}:${item.wakeTime.microsecondsSinceEpoch}:${item.duration.inMinutes}:${item.quality.name}:${item.notes}',
        )
        .join('|');
    return _SleepScreenSelection(
      items: visibleItems,
      signature: '${items.length}::$signature',
    );
  }

  final List<Sleep> items;
  final String signature;

  @override
  bool operator ==(Object other) =>
      other is _SleepScreenSelection && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}
