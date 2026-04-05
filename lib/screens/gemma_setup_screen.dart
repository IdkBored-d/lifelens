import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_services.dart';
import '../services/gemma_model_manager.dart';

/// Shown once after onboarding when Gemma hasn't been configured yet.
///
/// Three paths through this screen:
///
///  1. **Download** — streams the model from the network with a progress bar.
///     Requires [GemmaModelManager.modelUrl] to be filled in.
///
///  2. **Dev / local path** — enter the absolute path to a pre-downloaded
///     .bin file already on the device (e.g. pushed via `adb push`).
///     Intended for MVP testing so you don't re-download the model each time.
///
///  3. **Skip** — uses cloud AI (Gemini) only. The screen won't reappear
///     unless the user manually navigates back to it from Settings.
///
/// [onComplete] is called after any of the three paths finishes.
class GemmaSetupScreen extends StatefulWidget {
  const GemmaSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<GemmaSetupScreen> createState() => _GemmaSetupScreenState();
}

class _GemmaSetupScreenState extends State<GemmaSetupScreen> {
  // ── State ─────────────────────────────────────────────────────────────────

  _Phase _phase = _Phase.idle;
  double _progress = 0.0;
  String? _errorMessage;
  bool _devExpanded = false;

  final _devPathController = TextEditingController(text: '/sdcard/Download/gemma2-2b-it-int8-web.task.bin');
  CancellationToken? _cancelToken;

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> _startDownload() async {
    if (GemmaModelManager.modelUrl.isEmpty) {
      setState(() {
        _errorMessage =
            'No download URL is configured yet.\n'
            'Use the Dev mode below to load a local file.';
      });
      return;
    }

    setState(() {
      _phase        = _Phase.downloading;
      _progress     = 0.0;
      _errorMessage = null;
    });

    _cancelToken = CancellationToken();

    try {
      final path = await GemmaModelManager.downloadModel(
        cancel: _cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      await GemmaModelManager.savePath(path);
      await AppServices.loadGemmaModel(path);

      if (mounted) setState(() => _phase = _Phase.done);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase        = _Phase.idle;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() {
      _phase        = _Phase.idle;
      _progress     = 0.0;
      _errorMessage = 'Download cancelled.';
    });
  }

  // ── Dev / local-path load ─────────────────────────────────────────────────
  // TODO(prod): Remove this entire dev/local-path flow before release —
  // loading from /sdcard is a testing convenience only; production should use
  // the OTA download path exclusively.

  Future<void> _loadLocalPath() async {
    // ── Android storage permission ────────────────────────────────────────────
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) {
        // All files access already granted — proceed.
      } else if (await Permission.storage.request().isGranted) {
        // READ_EXTERNAL_STORAGE granted (Android ≤ 12) — proceed.
      } else {
        // Android 11+: .request() opens the "All Files Access" system page.
        // Do NOT call openAppSettings() afterwards — the request already handled it.
        final granted = await Permission.manageExternalStorage.request().isGranted;
        if (!granted) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Storage access is required to load the model.\n\n'
                  'Grant "All files access" for LifeLens in:\n'
                  'Settings → Apps → LifeLens → Permissions → Files and media\n\n'
                  'Then tap "Load from path" again.';
            });
          }
          return;
        }
      }
    }

    final path = _devPathController.text.trim();
    final error = await GemmaModelManager.validateLocalPath(path);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _phase        = _Phase.loading;
      _errorMessage = null;
    });

    try {
      await AppServices.loadGemmaModel(path);
      await GemmaModelManager.savePath(path);

      if (mounted) setState(() => _phase = _Phase.done);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase        = _Phase.idle;
          _errorMessage = 'Failed to load model: $e';
        });
      }
    }
  }

  // ── Skip ──────────────────────────────────────────────────────────────────

  Future<void> _skip() async {
    await GemmaModelManager.markSkipped();
    widget.onComplete();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelToken?.cancel();
    _devPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Icon(Icons.memory_rounded,
                  size: 56, color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Set Up On-Device AI',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Download Gemma 2 2B to analyze your mood, symptoms, and '
                'health data directly on your device. It works offline and '
                'keeps everything private.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // ── Download section ──────────────────────────────────────────
              _DownloadCard(
                phase:      _phase,
                progress:   _progress,
                onDownload: _startDownload,
                onCancel:   _cancelDownload,
              ),

              // ── Error banner ──────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _errorMessage!),
              ],

              const SizedBox(height: 28),

              // ── Dev / local path ──────────────────────────────────────────
              _DevModePanel(
                expanded:   _devExpanded,
                controller: _devPathController,
                enabled:    _phase == _Phase.idle,
                onToggle:   () => setState(() => _devExpanded = !_devExpanded),
                onLoad:     _loadLocalPath,
              ),

              const SizedBox(height: 36),

              // ── Skip ──────────────────────────────────────────────────────
              if (_phase == _Phase.idle)
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip for now — use cloud AI only',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.phase,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
  });

  final _Phase       phase;
  final double       progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_outlined,
                    color: colorScheme.primary),
                const SizedBox(width: 10),
                Text('Download model  (~1.4 GB)',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),

            if (phase == _Phase.downloading || phase == _Phase.done) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: phase == _Phase.done ? 1.0 : progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                phase == _Phase.done
                    ? 'Complete!'
                    : '${(progress * 100).toStringAsFixed(1)} %',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ],

            const SizedBox(height: 16),

            switch (phase) {
              _Phase.idle => FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
              _Phase.downloading => OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                ),
              _Phase.loading => const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
              _Phase.done => Icon(Icons.check_circle_outline_rounded,
                  color: colorScheme.primary, size: 28),
            },
          ],
        ),
      ),
    );
  }
}

class _DevModePanel extends StatelessWidget {
  const _DevModePanel({
    required this.expanded,
    required this.controller,
    required this.enabled,
    required this.onToggle,
    required this.onLoad,
  });

  final bool                  expanded;
  final TextEditingController controller;
  final bool                  enabled;
  final VoidCallback          onToggle;
  final VoidCallback          onLoad;

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.developer_mode_rounded,
                color: colorScheme.secondary),
            title: const Text('Dev / Testing mode'),
            subtitle: const Text('Load a pre-downloaded local file'),
            trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste the absolute path to a .bin model file '
                    'already on this device.\n\n'
                    'Example (after adb push):\n'
                    '  /sdcard/Download/gemma-2-2b-it-gpu-int8.bin',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller:  controller,
                    enabled:     enabled,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Model file path',
                      hintText:
                          '/sdcard/Download/gemma-2-2b-it-gpu-int8.bin',
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: enabled ? onLoad : null,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Load from path'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

// ── Phase enum ────────────────────────────────────────────────────────────────

enum _Phase { idle, downloading, loading, done }
