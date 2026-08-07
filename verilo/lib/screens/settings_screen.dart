import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_scope.dart';
import '../main.dart' show displayScale, kDisplayScaleKey;
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// Settings: edit name/DOB/company/role freely. Email and phone are guarded —
/// each change sends a one-time code (valid 5 minutes) and applies only after
/// the code verifies.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  DateTime? _dob;
  bool _saving = false;

  // email change flow
  final _newEmailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  bool _emailCodeSent = false;
  bool _emailBusy = false;

  // phone change flow (verified with a code sent to the account email —
  // SMS delivery isn't configured, and the email already proves it's you)
  final _newPhoneCtrl = TextEditingController();
  final _phoneCodeCtrl = TextEditingController();
  bool _phoneCodeSent = false;
  bool _phoneBusy = false;

  Map<String, dynamic> get _meta => authService.currentSession?.user.userMetadata ?? {};
  String get _email => authService.currentSession?.user.email ?? '';

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = (_meta['name'] as String?) ?? '';
    _companyCtrl.text = (_meta['company'] as String?) ?? '';
    _roleCtrl.text = (_meta['role'] as String?) ?? '';
    _dob = DateTime.tryParse((_meta['dob'] as String?) ?? '');
    if (_dob != null) _dobCtrl.text = _fmtDob(_dob!);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _dobCtrl, _companyCtrl, _roleCtrl, _newEmailCtrl, _emailCodeCtrl, _newPhoneCtrl, _phoneCodeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      setState(() { _dob = picked; _dobCtrl.text = _fmtDob(picked); });
    }
  }

  Future<void> _saveBasics() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Name can\'t be empty');
      return;
    }
    setState(() => _saving = true);
    try {
      await authService.updateFields({
        'name': _nameCtrl.text.trim(),
        if (_dob != null) 'dob': _dob!.toIso8601String(),
        'company': _companyCtrl.text.trim(),
        'role': _roleCtrl.text.trim(),
      });
      _toast('Saved');
    } catch (_) {
      _toast('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendEmailChangeCode() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (!newEmail.contains('@')) {
      _toast('Enter a valid email address');
      return;
    }
    setState(() => _emailBusy = true);
    try {
      await authService.requestEmailChange(newEmail);
      setState(() => _emailCodeSent = true);
      _toast('Code sent to $newEmail');
    } catch (_) {
      _toast('Could not send the code. Check the address and try again.');
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _verifyEmailChange() async {
    setState(() => _emailBusy = true);
    try {
      await authService.verifyEmailChange(_newEmailCtrl.text.trim(), _emailCodeCtrl.text.trim());
      _toast('Email updated');
      setState(() { _emailCodeSent = false; _newEmailCtrl.clear(); _emailCodeCtrl.clear(); });
    } catch (_) {
      _toast('That code didn\'t verify. Check it or resend — codes expire after 5 minutes.');
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _sendPhoneChangeCode() async {
    if (_newPhoneCtrl.text.trim().length < 8) {
      _toast('Enter a valid phone number');
      return;
    }
    setState(() => _phoneBusy = true);
    try {
      await authService.sendEmailOtp(_email);
      setState(() => _phoneCodeSent = true);
      _toast('Code sent to $_email');
    } catch (_) {
      _toast('Could not send the code. Try again.');
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  Future<void> _verifyPhoneChange() async {
    setState(() => _phoneBusy = true);
    try {
      await authService.verifyEmailOtp(_email, _phoneCodeCtrl.text.trim());
      await authService.updateFields({'phone': _newPhoneCtrl.text.trim()});
      _toast('Phone number updated');
      setState(() { _phoneCodeSent = false; _newPhoneCtrl.clear(); _phoneCodeCtrl.clear(); });
    } catch (_) {
      _toast('That code didn\'t verify. Check it or resend — codes expire after 5 minutes.');
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Text('Settings', style: AppText.screenTitle),
                  ],
                ),
                const SizedBox(height: 24),
                Text('DISPLAY', style: AppText.label),
                const SizedBox(height: 6),
                Text('Makes all text and controls in the app larger or smaller. Applies immediately.',
                    style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 4),
                ValueListenableBuilder<double>(
                  valueListenable: displayScale,
                  builder: (context, scale, _) => Row(
                    children: [
                      Text('A', style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: scale,
                          min: 0.85,
                          max: 1.3,
                          divisions: 9,
                          activeColor: AppColors.copperMid,
                          inactiveColor: AppColors.bgCardElevated,
                          label: '${(scale * 100).round()}%',
                          onChanged: (v) => displayScale.value = v,
                          onChangeEnd: (v) async =>
                              (await SharedPreferences.getInstance()).setDouble(kDisplayScaleKey, v),
                        ),
                      ),
                      Text('A', style: AppText.spaceGrotesk(size: 19, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text('${(scale * 100).round()}%',
                            textAlign: TextAlign.end, style: AppText.jetBrainsMono(size: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('PERSONAL', style: AppText.label),
                const SizedBox(height: 12),
                AppTextField(label: 'Full name', controller: _nameCtrl),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: AppTextField(label: 'Date of birth', hint: 'DD/MM/YYYY', controller: _dobCtrl, icon: Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Company / Organisation', controller: _companyCtrl),
                const SizedBox(height: 12),
                AppTextField(label: 'Role', controller: _roleCtrl),
                const SizedBox(height: 16),
                CopperButton(label: _saving ? 'Saving…' : 'Save changes', onTap: _saving ? () {} : _saveBasics),
                const SizedBox(height: 28),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 24),
                Text('EMAIL', style: AppText.label),
                const SizedBox(height: 6),
                Text('Signed in as $_email. Changing it sends a code to the new address; nothing changes until the code verifies. Codes expire after 5 minutes.',
                    style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 12),
                AppTextField(label: 'New email', hint: 'you@yourorg.in', controller: _newEmailCtrl,
                    keyboardType: TextInputType.emailAddress),
                if (_emailCodeSent) ...[
                  const SizedBox(height: 12),
                  AppTextField(label: 'Verification code', hint: 'e.g. 123456', controller: _emailCodeCtrl,
                      keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 12),
                CopperButton(
                  label: _emailBusy ? 'Working…' : (_emailCodeSent ? 'Verify & change email' : 'Send code'),
                  onTap: _emailBusy ? () {} : (_emailCodeSent ? _verifyEmailChange : _sendEmailChangeCode),
                ),
                const SizedBox(height: 28),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 24),
                Text('PHONE', style: AppText.label),
                const SizedBox(height: 6),
                Text('Current: ${(_meta['phone'] as String?) ?? '—'}. Changing it sends a code to your email to confirm it\'s you. Codes expire after 5 minutes.',
                    style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 12),
                AppTextField(label: 'New phone number', hint: '+91 98765 43210', controller: _newPhoneCtrl,
                    keyboardType: TextInputType.phone),
                if (_phoneCodeSent) ...[
                  const SizedBox(height: 12),
                  AppTextField(label: 'Verification code', hint: 'e.g. 123456', controller: _phoneCodeCtrl,
                      keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 12),
                CopperButton(
                  label: _phoneBusy ? 'Working…' : (_phoneCodeSent ? 'Verify & change phone' : 'Send code'),
                  onTap: _phoneBusy ? () {} : (_phoneCodeSent ? _verifyPhoneChange : _sendPhoneChangeCode),
                ),
              ],
            ),
          ),
        ),
      );
}
