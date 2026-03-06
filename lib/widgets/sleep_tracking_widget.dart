import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';

class SleepTrackingWidget extends StatefulWidget {
  const SleepTrackingWidget({super.key, required this.onSleepLogged});

  final Function(Sleep) onSleepLogged;

  @override
  State<SleepTrackingWidget> createState() => _SleepTrackingWidgetState();
}

class _SleepTrackingWidgetState extends State<SleepTrackingWidget> {
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;
  SleepQuality? _quality;
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined, color: cs.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Log Your Sleep',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _TimeSelector(
            label: 'Bedtime',
            icon: Icons.nightlight_round,
            time: _bedTime,
            onTimeSelected: (time) => setState(() => _bedTime = time),
          ),

          const SizedBox(height: 16),

          _TimeSelector(
            label: 'Wake Time',
            icon: Icons.wb_sunny_outlined,
            time: _wakeTime,
            onTimeSelected: (time) => setState(() => _wakeTime = time),
          ),

          const SizedBox(height: 20),
          Text(
            'How did you sleep?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: sleepQualities.map((quality) => 
              ChoiceChip(
                label: Text('${quality.emoji} ${quality.label}'),
                selected: _quality == quality,
                onSelected: (_) => setState(() => _quality = quality),
                backgroundColor: cs.primaryContainer,
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                labelStyle: TextStyle(
                  color: _quality == quality ? cs.onPrimaryContainer: cs.onSurface,
                  fontWeight: _quality == quality ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              ).toList(),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'How was your sleep?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSave ? _saveSleep : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Sleep Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSave =>
    _bedTime != null && _wakeTime != null && _quality != null;

  void _saveSleep() {
    if (!_canSave) return;

    final now = DateTime.now();
    final bedDateTime = DateTime(
      now.year, now.month, now.day, _bedTime!.hour, _bedTime!.minute,
    );
    
    final wakeDateTime = DateTime(
      now.year, now.month, now.day, _wakeTime!.hour, _wakeTime!.minute,
    );

    final sleep = Sleep(
      bedTime: bedDateTime,
      wakeTime: wakeDateTime,
      quality: _quality!,
      date: now,
      notes: _notesController.text.trim(),
    );

    widget.onSleepLogged(sleep);

    setState(() {
      _bedTime = null;
      _wakeTime = null;
      _quality = null;
      _notesController.clear();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTimeSelected,
  });

  final String label;
  final IconData icon;
  final TimeOfDay? time;
  final Function(TimeOfDay) onTimeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (selectedTime != null) {
          onTimeSelected(selectedTime);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 2),
                  Text(
                    time?.format(context) ?? 'Select time',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: time != null ? cs.onSurface: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.schedule,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}