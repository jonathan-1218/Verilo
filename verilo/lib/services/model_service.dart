import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/database.dart';

/// Downloads and tracks the Whisper + Gemma model files.
class ModelService {
  ModelService(this._db);
  final AppDatabase _db;
  final _dio = Dio();

  // whisper: large-v3-turbo-q5 bin for whisper.cpp (used by whisper_flutter_new)
  static const _whisperUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin';
  // gemma: MediaPipe .task format required by flutter_gemma (not GGUF)
  // ponytail: swap to gemma-3-1b-it if 2b is too large for target devices
  static const _gemmaUrl =
      'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-2b-it/float32/1/gemma-2b-it.task';

  Future<String> _modelDir() async {
    final dir = await getApplicationSupportDirectory();
    final models = Directory('${dir.path}/models');
    if (!models.existsSync()) models.createSync(recursive: true);
    return models.path;
  }

  Future<bool> isReady(String key) async {
    final m = await _db.modelFile(key);
    if (m == null) return false;
    return File(m.filePath).existsSync();
  }

  /// Returns the local path once done, or throws.
  Future<String> download(
    String key,
    void Function(double progress) onProgress,
  ) async {
    final dir = await _modelDir();
    final url = key == 'whisper' ? _whisperUrl : _gemmaUrl;
    final ext = key == 'whisper' ? 'bin' : 'task';
    final path = '$dir/$key.$ext';

    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    final size = await File(path).length();
    await _db.upsertModelFile(ModelFilesCompanion.insert(
      key: key,
      filePath: path,
      sizeBytes: size,
    ));
    return path;
  }

  Future<String?> pathFor(String key) async {
    final m = await _db.modelFile(key);
    return m?.filePath;
  }
}
