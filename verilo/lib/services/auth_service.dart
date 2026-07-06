import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase auth: 6-digit email OTP + Google/Outlook OAuth.
/// OAuth redirects back into the app via the com.verilo.verilo://login-callback
/// deep link registered in AndroidManifest.xml; the email OTP flow needs no
/// deep link — the user types the code straight into the app.
class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  static const _redirectTo = 'com.verilo.verilo://login-callback';

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  bool get isSignedIn => currentSession != null;
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<void> sendEmailOtp(String email) => _auth.signInWithOtp(email: email);

  Future<void> verifyEmailOtp(String email, String code) =>
      _auth.verifyOTP(type: OtpType.email, token: code, email: email);

  Future<void> signInWithGoogle() => _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectTo,
      );

  Future<void> signInWithOutlook() => _auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: _redirectTo,
        scopes: 'openid email profile',
      );

  Future<void> signOut() => _auth.signOut();

  /// Required profile fields collected once, right after first sign-in.
  /// Stored in Supabase's user_metadata (not a separate table): it's already
  /// scoped to the signed-in user with no extra RLS to write, and Google/
  /// Outlook sign-ins pre-fill `name` here automatically via OAuth consent.
  static const profileFields = ['name', 'dob', 'company', 'role', 'phone'];

  bool get profileComplete {
    final meta = _auth.currentUser?.userMetadata;
    if (meta == null) return false;
    return profileFields.every((f) => (meta[f] as String?)?.isNotEmpty == true);
  }

  Future<void> updateProfile({
    required String name,
    required String dob,
    required String company,
    required String role,
    required String phone,
  }) =>
      _auth.updateUser(UserAttributes(data: {
        'name': name,
        'dob': dob,
        'company': company,
        'role': role,
        'phone': phone,
      }));
}
