import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/database.dart';

/// Downloads and tracks the on-device Whisper model file.
/// (Gemma was dropped: its public download URL is gone and its inference was
/// never wired — the cloud summary covers that path.)
class ModelService {
  ModelService(this._db);
  final AppDatabase _db;
  final _dio = Dio();

  // whisper: ggml 'base' — ~4x faster than 'small' on phone CPUs, which is
  // what field use needs; accuracy on short dictated notes is close enough.
  // The filename must match the package's ggml-<model>.bin convention so it
  // finds the file instead of re-downloading its own copy.
  // (must stay in step with WhisperModel.base in whisper_service.dart)
  static const whisperFileName = 'ggml-base.bin';
  static const _whisperUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$whisperFileName';
  Future<String> _modelDir() async {
    final dir = await getApplicationSupportDirectory();
    final models = Directory('${dir.path}/models');
    if (!models.existsSync()) models.createSync(recursive: true);
    return models.path;
  }

  // sticky-true cache: the router's redirect checks readiness on every
  // navigation, and once the model is on disk it doesn't vanish mid-session
  bool _whisperReady = false;

  Future<bool> isReady(String key) async {
    if (key == 'whisper' && _whisperReady) return true;
    final m = await _db.modelFile(key);
    if (m == null) return false;
    // a whisper file downloaded under the old naming can't be loaded by the
    // runtime — report not-ready so the screen offers a re-download
    if (key == 'whisper' && !m.filePath.endsWith(whisperFileName)) return false;
    final ready = File(m.filePath).existsSync();
    if (key == 'whisper') _whisperReady = ready;
    return ready;
  }

  /// Returns the local path once done, or throws.
  Future<String> download(
    String key,
    void Function(double progress) onProgress,
  ) async {
    if (key != 'whisper') throw ArgumentError('unknown model: $key');
    final dir = await _modelDir();
    const url = _whisperUrl;
    final path = '$dir/$whisperFileName';

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
