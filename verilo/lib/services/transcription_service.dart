import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloud transcription fallback (Deepgram Nova-3). Strictly opt-in and
/// fail-quiet: flag off, missing key, offline, or a bad response all return
/// null — the clip just keeps its empty transcript, capture never breaks.
class TranscriptionService {
  final _dio = Dio();

  static const prefsKey = 'cloud_transcription_enabled';

  Future<bool> get enabled async =>
      (await SharedPreferences.getInstance()).getBool(prefsKey) ?? false;

  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(prefsKey, value);

  Future<String?> transcribe(String filePath) async {
    try {
      if (!await enabled) return null;
      final key = dotenv.maybeGet('DEEPGRAM_API_KEY') ?? '';
      if (key.isEmpty) return null;

      final bytes = await File(filePath).readAsBytes();
      final res = await _dio.post<Map<String, dynamic>>(
        'https://api.deepgram.com/v1/listen',
        queryParameters: {'model': 'nova-3', 'smart_format': 'true'},
        options: Options(headers: {
          'Authorization': 'Token $key',
          'Content-Type': filePath.endsWith('.wav') ? 'audio/wav' : 'audio/m4a',
          Headers.contentLengthHeader: bytes.length,
        }),
        data: Stream.fromIterable([bytes]),
      );
      final transcript = res.data?['results']?['channels']?[0]?['alternatives']?[0]
          ?['transcript'] as String?;
      final trimmed = transcript?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (_) {
      return null;
    }
  }
}
