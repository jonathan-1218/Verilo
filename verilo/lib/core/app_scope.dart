import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';
import 'repository.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/transcription_service.dart';
import '../services/summary_service.dart';
import '../services/seal_service.dart';
import '../services/model_service.dart';
import '../services/whisper_service.dart';

/// App-wide singletons. Lazily created on first access, which is always
/// after main() has finished Supabase.initialize().
final appDatabase = AppDatabase();
final transcriptionService = TranscriptionService();
final summaryService = SummaryService(transcriptionService);
final appRepository = AppRepository(
  appDatabase,
  Supabase.instance.client,
  // on-device whisper first (if the model is downloaded), cloud fallback
  // second (if the user opted in) — both fail-quiet to an empty transcript
  transcriber: (path) async =>
      await whisperService.transcribe(path) ?? await transcriptionService.transcribe(path),
);
final locationService = LocationService();
final photoService = PhotoService(appDatabase, locationService);
final audioService = AudioService();
final authService = AuthService(Supabase.instance.client);
final sealService = SealService();
final modelService = ModelService(appDatabase);
final whisperService = WhisperService(modelService);

String get currentOfficerName {
  final user = Supabase.instance.client.auth.currentUser;
  final meta = user?.userMetadata;
  // 'name' is the field our own profile-setup screen writes; 'full_name' is
  // what Google/Outlook OAuth pre-fills before that screen runs
  return (meta?['name'] as String?) ?? (meta?['full_name'] as String?) ?? user?.email ?? 'Field Officer';
}
