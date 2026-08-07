import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'transcription_service.dart';

/// Cloud AI summary for the report's "AI Summary" section. Reuses the same
/// Deepgram key and the same opt-in flag as TranscriptionService (Task 2) —
/// no new API key, no new setting. Fails quiet: flag off, missing key,
/// offline, or a bad response all fall back to the raw notes.
class SummaryService {
  SummaryService(this._transcription);
  final TranscriptionService _transcription;
  final _dio = Dio();

  Future<String> summarize(List<String> transcripts, String notes) async {
    try {
      if (!await _transcription.enabled) return notes;
      final key = dotenv.maybeGet('DEEPGRAM_API_KEY') ?? '';
      if (key.isEmpty) return notes;

      final text = [...transcripts.where((t) => t.trim().isNotEmpty), notes].join('\n\n');
      if (text.trim().isEmpty) return notes;

      final res = await _dio.post<Map<String, dynamic>>(
        'https://api.deepgram.com/v1/read',
        queryParameters: {'summarize': 'v2'},
        options: Options(headers: {
          'Authorization': 'Token $key',
          'Content-Type': 'application/json',
        }),
        data: {'text': text},
      );
      final summary = res.data?['results']?['summary']?['text'] as String?;
      final trimmed = summary?.trim();
      return (trimmed == null || trimmed.isEmpty) ? notes : trimmed;
    } catch (_) {
      return notes;
    }
  }
}
