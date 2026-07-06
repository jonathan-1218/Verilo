import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioService {
  final _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    if (!await requestPermission()) return false;
    final dir = await getApplicationDocumentsDirectory();
    _currentPath = '${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 16000),
      path: _currentPath!,
    );
    return true;
  }

  /// Returns the saved file path.
  Future<String?> stopRecording() async {
    await _recorder.stop();
    return _currentPath;
  }

  Future<void> dispose() => _recorder.dispose();
}
