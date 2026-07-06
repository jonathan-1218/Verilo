import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _auth = AuthService(Supabase.instance.client);
  bool _busy = false;
  bool _resending = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // raw exception text leaks internals (URLs, stack fragments) and reads as
  // gibberish — map to short human messages before display
  String _friendly(Object e) {
    final m = e.toString();
    if (m.contains('SocketException') || m.contains('Failed host lookup') || m.contains('Connection')) {
      return "Can't reach the server. Check your internet connection and try again.";
    }
    if (m.contains('rate limit') || m.contains('429')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return 'That code is wrong or has expired. Check it or resend a new one.';
    }
    if (e is AuthException && !e.message.contains('Exception')) return e.message;
    return 'Sign-in failed. Please try again.';
  }

  // OTP length is a Supabase dashboard setting (not fixed at 6), so only
  // check the code is numeric and non-empty — let the server be the judge
  // of whether it's actually correct.
  Future<void> _run(Future<void> Function() action, {VoidCallback? onSuccess, void Function(bool)? setBusy}) async {
    final setter = setBusy ?? (v) => setState(() => _busy = v);
    setter(true);
    setState(() => _error = null);
    try {
      await action();
      onSuccess?.call();
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setter(false);
    }
  }

  void _sendCode() {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.') || email.length < 5) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    _run(() => _auth.sendEmailOtp(email), onSuccess: () {
      _codeCtrl.clear();
      setState(() => _codeSent = true);
    });
  }

  void _resendCode() {
    _run(
      () => _auth.sendEmailOtp(_emailCtrl.text.trim()),
      onSuccess: () => _codeCtrl.clear(),
      setBusy: (v) => setState(() => _resending = v),
    );
  }

  void _verifyCode() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || int.tryParse(code) == null) {
      setState(() => _error = 'Enter the code from the email');
      return;
    }
    // on success the auth state change triggers the router redirect to /dashboard
    _run(() => _auth.verifyEmailOtp(_emailCtrl.text.trim(), code));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VeriloLogo(),
                const SizedBox(height: 36),
                Text('Sign in', style: AppText.spaceGrotesk(size: 24, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  _codeSent
                      ? 'Enter the sign-in code we emailed to ${_emailCtrl.text.trim()}.'
                      : "We'll email you a sign-in code. No password needed.",
                  style: AppText.spaceGrotesk(size: 14, color: AppColors.textSecondary, height: 1.55),
                ),
                const SizedBox(height: 28),
                if (_codeSent) ...[
                  AppTextField(
                    label: 'Verification code',
                    hint: 'e.g. 123456',
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: AppText.spaceGrotesk(size: 12, color: AppColors.red)),
                  ],
                  const SizedBox(height: 10),
                  CopperButton(
                    label: _busy ? 'Verifying…' : 'Verify & Sign In',
                    onTap: _busy ? () {} : _verifyCode,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _resending ? null : _resendCode,
                        child: Text(_resending ? 'Sending…' : 'Resend code', style: AppText.spaceGrotesk(size: 13, color: AppColors.copperMid)),
                      ),
                      Text('   ·   ', style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted)),
                      GestureDetector(
                        onTap: () => setState(() { _codeSent = false; _error = null; }),
                        child: Text('Change email', style: AppText.spaceGrotesk(size: 13, color: AppColors.copperMid)),
                      ),
                    ],
                  ),
                ] else ...[
                  AppTextField(
                    label: 'Work email',
                    hint: 'you@yourorg.in',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: AppText.spaceGrotesk(size: 12, color: AppColors.red)),
                  ],
                  const SizedBox(height: 10),
                  CopperButton(
                    label: _busy ? 'Sending…' : 'Send Code',
                    onTap: _busy ? () {} : _sendCode,
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(child: Divider(color: AppColors.borderSubtle)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
                    ),
                    const Expanded(child: Divider(color: AppColors.borderSubtle)),
                  ]),
                  const SizedBox(height: 18),
                  _OAuthButton(
                    initial: 'G',
                    label: 'Continue with Google',
                    onTap: () => _run(_auth.signInWithGoogle),
                  ),
                  const SizedBox(height: 10),
                  _OAuthButton(
                    initial: 'O',
                    label: 'Continue with Outlook',
                    onTap: () => _run(_auth.signInWithOutlook),
                  ),
                ],
                const SizedBox(height: 32),
                Center(
                  child: Text('Your data stays on your device\nuntil you choose to sync.',
                      style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted, height: 1.65),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      );
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({required this.initial, required this.label, required this.onTap});
  final String initial, label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Center(
                  child: Text(initial, style: AppText.spaceGrotesk(size: 10, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w500)),
            ],
          ),
        ),
      );
}
