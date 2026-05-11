import 'package:flutter/foundation.dart' show debugPrint;
import 'package:background_fetch/background_fetch.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';

/// Schedules and handles the once-per-day background EOD pipeline.
///
/// Call [register] once at startup (from app_init.dart).
/// The OS triggers the task at most once per [_intervalMinutes] minutes;
/// in practice this happens in the evening on most devices.
///
/// A duplicate-run guard checks whether today's EodEntry already exists in
/// Isar — if so, the task is a no-op. This prevents double writes when both
/// the Mini-Me "Day Summary" button and the background task fire on the same day.
class BackgroundEodService {
  BackgroundEodService._();

  static const String _taskId          = 'com.lifelens.eod_pipeline';
  static const int    _intervalMinutes = 1440; // 24 hours (OS-controlled)

  /// Register the background fetch task. Safe to call multiple times.
  static Future<void> register() async {
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval:  _intervalMinutes,
        stopOnTerminate:       false,
        enableHeadless:        true,
        requiresBatteryNotLow: false,
        requiresCharging:      false,
        requiresStorageNotLow: false,
        startOnBoot:           true,
      ),
      _onFetch,
      _onTimeout,
    );

    // Register the named task so the headless callback can identify it.
    await BackgroundFetch.scheduleTask(TaskConfig(
      taskId:            _taskId,
      delay:             0,           // fire as soon as the OS allows
      periodic:          true,
      forceAlarmManager: false,
      stopOnTerminate:   false,
      enableHeadless:    true,
    ));

    debugPrint('[BackgroundEodService] registered (interval=${_intervalMinutes}min)');
  }

  /// Called when the OS fires the background fetch event (app foregrounded).
  static Future<void> _onFetch(String taskId) async {
    debugPrint('[BackgroundEodService] fetch fired taskId=$taskId');
    try {
      await _runEodIfNeeded();
      await TrackingReminderService.instance.init();
      await TrackingReminderService.instance.evaluateAndNotifyIfNeeded();
    } catch (e) {
      debugPrint('[BackgroundEodService] error: $e');
    } finally {
      BackgroundFetch.finish(taskId);
    }
  }

  /// Called when the OS is about to kill the background task (30-second window exceeded).
  static void _onTimeout(String taskId) {
    debugPrint('[BackgroundEodService] timeout taskId=$taskId');
    BackgroundFetch.finish(taskId);
  }

  /// Run the EOD pipeline only if it hasn't already run today.
  static Future<void> _runEodIfNeeded() async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    // Duplicate-run guard: skip if today's EodEntry already exists in Isar.
    final existing = await AppServices.isar.getEodEntry(todayStr);
    if (existing != null) {
      debugPrint('[BackgroundEodService] EOD already run for $todayStr — skipping');
      return;
    }

    final online = await AppServices.isOnline();
    await AppServices.eodPipeline.runEndOfDay(isOnline: online);
    debugPrint('[BackgroundEodService] EOD pipeline completed for $todayStr');
  }
}

/// Top-level headless callback — required by flutter_background_fetch when
/// the app is terminated. Must be a top-level (not instance) function.
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  final taskId    = task.taskId;
  final isTimeout = task.timeout;

  if (isTimeout) {
    debugPrint('[BackgroundEodService] headless timeout taskId=$taskId');
    BackgroundFetch.finish(taskId);
    return;
  }

  debugPrint('[BackgroundEodService] headless fetch taskId=$taskId');
  try {
    // AppServices must be re-initialised in the headless isolate — it has
    // no shared memory with the foreground isolate. Skip MiniGen: the 30s
    // budget cannot accommodate a ~96 MB download/load.
    await AppServices.init(skipMiniGen: true);
    await BackgroundEodService._runEodIfNeeded();
    await TrackingReminderService.instance.init();
    await TrackingReminderService.instance.evaluateAndNotifyIfNeeded();
  } catch (e) {
    debugPrint('[BackgroundEodService] headless error: $e');
  } finally {
    BackgroundFetch.finish(taskId);
  }
}
