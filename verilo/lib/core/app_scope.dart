import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';
import 'repository.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';

/// App-wide singletons. Lazily created on first access, which is always
/// after main() has finished Supabase.initialize().
final appDatabase = AppDatabase();
final appRepository = AppRepository(appDatabase, Supabase.instance.client);
final locationService = LocationService();
final photoService = PhotoService(appDatabase, locationService);
final audioService = AudioService();
final authService = AuthService(Supabase.instance.client);

String get currentOfficerName {
  final user = Supabase.instance.client.auth.currentUser;
  final meta = user?.userMetadata;
  // 'name' is the field our own profile-setup screen writes; 'full_name' is
  // what Google/Outlook OAuth pre-fills before that screen runs
  return (meta?['name'] as String?) ?? (meta?['full_name'] as String?) ?? user?.email ?? 'Field Officer';
}
