import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verilo/main.dart';
import 'package:verilo/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'seen_onboarding': true});
    await Supabase.initialize(url: 'https://test.supabase.co', anonKey: 'test-key');
  });

  testWidgets('boots to login when signed out', (tester) async {
    await tester.pumpWidget(const VeriloApp());
    await tester.pump(const Duration(seconds: 2)); // splash delay
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
