import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// One-time gate after sign-in: the Whisper model is required so voice notes
/// transcribe on-device. The router redirects here until it's downloaded.
class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    setState(() { _downloading = true; _progress = 0; _error = null; });
    try {
      await modelService.download('whisper', (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed. Check your connection and tap to retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VeriloLogo(),
                const Spacer(),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.copperMid.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.graphic_eq, size: 26, color: AppColors.copperMid),
                ),
                const SizedBox(height: 20),
                Text('One-time setup', style: AppText.spaceGrotesk(size: 22, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Verilo transcribes voice notes on this device — audio never has to leave your phone. '
                  'That needs the Whisper speech model (~142 MB), downloaded once.',
                  style: AppText.spaceGrotesk(size: 14, color: AppColors.textSecondary, height: 1.55),
                ),
                const SizedBox(height: 28),
                if (_downloading) ...[
                  CopperProgressBar(value: _progress, height: 7),
                  const SizedBox(height: 10),
                  Text('${(_progress * 100).toStringAsFixed(0)}% — keep the app open',
                      style: AppText.jetBrainsMono(size: 11)),
                ] else
                  CopperButton(label: 'Download model', onTap: _download),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: AppText.spaceGrotesk(size: 12, color: AppColors.red)),
                  ),
                ],
                const Spacer(),
                Center(
                  child: Text('Voice capture, photos, and reports unlock right after this.',
                      style: AppText.spaceGrotesk(size: 11, color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      );
}
