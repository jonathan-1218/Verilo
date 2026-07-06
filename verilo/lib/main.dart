import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/colors.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  runApp(const VeriloApp());
}

class VeriloApp extends StatelessWidget {
  const VeriloApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Verilo',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
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
