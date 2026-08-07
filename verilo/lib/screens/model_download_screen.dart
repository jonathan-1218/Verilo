import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

class _ModelInfo {
  const _ModelInfo(this.key, this.name, this.description);
  final String key;
  final String name;
  final String description;
}

const _models = [
  _ModelInfo('whisper', 'Whisper', 'On-device voice transcription (whisper.cpp base, ~142MB)'),
];

/// Manages the optional on-device Whisper model — it runs for real once
/// downloaded (see WhisperService). AI summaries come from the cloud
/// fallback below.
class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final Map<String, bool> _ready = {};
  final Map<String, int?> _sizeBytes = {};
  final Map<String, double> _progress = {};
  final Map<String, bool> _downloading = {};
  bool _cloudEnabled = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cloud = await transcriptionService.enabled;
    if (!mounted) return;
    setState(() => _cloudEnabled = cloud);
    for (final m in _models) {
      final ready = await modelService.isReady(m.key);
      final file = await appDatabase.modelFile(m.key);
      if (!mounted) return;
      setState(() {
        _ready[m.key] = ready;
        _sizeBytes[m.key] = file?.sizeBytes;
      });
    }
  }

  Future<void> _setCloud(bool value) async {
    setState(() => _cloudEnabled = value);
    await transcriptionService.setEnabled(value);
  }

  Future<void> _download(String key) async {
    setState(() { _downloading[key] = true; _progress[key] = 0; });
    try {
      await modelService.download(key, (p) {
        if (mounted) setState(() => _progress[key] = p);
      });
    } catch (_) {
      // ponytail: no retry/backoff UI — offline or a bad connection just
      // leaves the model not-ready; tapping download again retries
    }
    if (!mounted) return;
    setState(() => _downloading[key] = false);
    await _refresh();
  }

  String _fmtSize(int? bytes) {
    if (bytes == null) return '';
    final mb = bytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        appBar: AppBar(
          backgroundColor: AppColors.bgApp,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => context.pop()),
          title: Text('On-device models', style: AppText.spaceGrotesk(size: 16, weight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Optional. Verilo works fully offline without these — download them only if you want on-device transcription and summaries instead of the cloud fallback.',
                style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              _cloudCard(),
              ..._models.map(_modelCard),
            ],
          ),
        ),
      );

  Widget _cloudCard() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CardSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud fallback', style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Transcribe voice notes and summarize reports via Deepgram when online. Audio leaves the device. Needs a DEEPGRAM_API_KEY baked into the app build.',
                        style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch(value: _cloudEnabled, onChanged: _setCloud, activeColor: AppColors.copperMid),
            ],
          ),
        ),
      );

  Widget _modelCard(_ModelInfo m) {
    final ready = _ready[m.key] ?? false;
    final downloading = _downloading[m.key] ?? false;
    final progress = _progress[m.key] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CardSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(m.description, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                StatusChip(
                  label: ready ? 'READY' : 'NOT DOWNLOADED',
                  color: ready ? AppColors.copperMid : AppColors.textMuted,
                ),
              ],
            ),
            if (ready && _sizeBytes[m.key] != null) ...[
              const SizedBox(height: 8),
              Text(_fmtSize(_sizeBytes[m.key]), style: AppText.jetBrainsMono(size: 10)),
            ],
            const SizedBox(height: 12),
            if (downloading) ...[
              CopperProgressBar(value: progress),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: AppText.jetBrainsMono(size: 10)),
            ] else if (!ready)
              CopperButton(label: 'Download', onTap: () => _download(m.key), fullWidth: false),
          ],
        ),
      ),
    );
  }
}
