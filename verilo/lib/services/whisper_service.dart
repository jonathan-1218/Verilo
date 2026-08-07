import 'dart:io';

import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'model_service.dart';

/// On-device transcription via whisper.cpp. Runs only when the Whisper model
/// has been downloaded from the models screen; every other case returns null
/// so the caller can fall back to cloud transcription (or no transcript).
class WhisperService {
  WhisperService(this._models);
  final ModelService _models;

  Future<String?> transcribe(String filePath) async {
    try {
      // whisper.cpp reads 16kHz WAV only — older clips were recorded as m4a
      if (!filePath.endsWith('.wav')) return null;
      if (!await _models.isReady('whisper')) return null;
      final modelPath = await _models.pathFor('whisper');
      if (modelPath == null) return null;

      final whisper = Whisper(
        model: WhisperModel.base, // must match ModelService.whisperFileName
        modelDir: File(modelPath).parent.path,
      );
      final res = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(audio: filePath, threads: 6),
      );
      final text = res.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null; // bad model file / OOM / unsupported audio → fall back
    }
  }
}
