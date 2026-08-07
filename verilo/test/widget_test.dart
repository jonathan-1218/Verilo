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
    // splash delay + extra frames for GoRouter's async redirect to resolve
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
