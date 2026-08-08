import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/colors.dart';
import 'core/router.dart';

/// App-wide display scale (0.85–1.3), applied as the text scaler at the root.
/// Adjusted from Settings, persisted across launches.
final displayScale = ValueNotifier<double>(1.0);
const kDisplayScaleKey = 'display_scale';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // ponytail: crash reporting is a no-op until SENTRY_DSN is set in .env —
  // add a project at sentry.io and drop the DSN in when ready to monitor prod.
  final sentryDsn = dotenv.maybeGet('SENTRY_DSN');
  if (sentryDsn == null || sentryDsn.isEmpty) {
    await _init();
  } else {
    await SentryFlutter.init(
      (options) => options
        ..dsn = sentryDsn
        ..tracesSampleRate = 0.2,
      appRunner: _init,
    );
  }
}

Future<void> _init() async {
  final (_, prefs) = await (
    Supabase.initialize(url: dotenv.get('SUPABASE_URL'), anonKey: dotenv.get('SUPABASE_ANON_KEY')),
    SharedPreferences.getInstance(),
  ).wait;
  displayScale.value = prefs.getDouble(kDisplayScaleKey) ?? 1.0;
  runApp(const VeriloApp());
}

class VeriloApp extends StatelessWidget {
  const VeriloApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Verilo',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: displayScale,
          builder: (context, scale, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: AppColors.copperMid,
            surface: AppColors.bgApp,
            onSurface: AppColors.textPrimary,
          ),
          scaffoldBackgroundColor: AppColors.bgApp,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
      );
}
