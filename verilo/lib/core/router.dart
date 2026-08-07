import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../core/app_scope.dart';
import '../screens/create_project_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/project_params_screen.dart';
import '../screens/visit_setup_screen.dart';
import '../screens/visit_capture_screen.dart';
import '../screens/report_screen.dart';
import '../screens/model_download_screen.dart';
import '../screens/model_setup_screen.dart';

/// Screens reachable before/without a signed-in session. Everything else
/// requires auth.
const _preAuthPaths = {'/', '/onboarding', '/login'};

/// Bridges the Supabase auth stream to GoRouter's refreshListenable so the
/// router re-evaluates `redirect` whenever sign-in state changes (e.g. after
/// a magic-link/OAuth deep link completes).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthRefresh(),
  redirect: (context, state) async {
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final isPreAuth = _preAuthPaths.contains(state.matchedLocation);
    if (!signedIn && !isPreAuth) return '/login';
    if (signedIn && isPreAuth) return '/dashboard';
    // completed profiles may still open /profile-setup deliberately (editing)
    if (signedIn && !authService.profileComplete && state.matchedLocation != '/profile-setup') {
      return '/profile-setup';
    }
    // on-device transcription is mandatory: gate everything after sign-in +
    // profile until the Whisper model is downloaded (sticky-cached once true)
    if (signedIn &&
        authService.profileComplete &&
        state.matchedLocation != '/model-setup' &&
        !await modelService.isReady('whisper')) {
      return '/model-setup';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
    GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/create-project', builder: (_, __) => const CreateProjectScreen()),
    GoRoute(
      path: '/project/:id',
      builder: (_, state) => ProjectDetailScreen(id: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'params',
          builder: (_, state) => ProjectParamsScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/visit-setup',
      builder: (_, state) => VisitSetupScreen(projectId: int.parse(state.uri.queryParameters['projectId']!)),
    ),
    GoRoute(
      path: '/visit-capture',
      builder: (_, state) => VisitCaptureScreen(visitId: int.parse(state.uri.queryParameters['visitId']!)),
    ),
    GoRoute(
      path: '/report',
      builder: (_, state) => ReportScreen(visitId: int.parse(state.uri.queryParameters['visitId']!)),
    ),
    GoRoute(path: '/model-download', builder: (_, __) => const ModelDownloadScreen()),
    GoRoute(path: '/model-setup', builder: (_, __) => const ModelSetupScreen()),
  ],
);
