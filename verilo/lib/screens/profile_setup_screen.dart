import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

const _roles = ['CSR Officer', 'Other'];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otherRoleCtrl = TextEditingController();
  String _role = 'CSR Officer';
  DateTime? _dob;
  bool _saving = false;
  String? _error;

  String get _email => authService.currentSession?.user.email ?? '';

  @override
  void initState() {
    super.initState();
    // Google/Outlook OAuth already hands us a display name — prefill it so
    // the user only has to confirm it, not retype it.
    final meta = authService.currentSession?.user.userMetadata;
    _nameCtrl.text = (meta?['full_name'] as String?) ?? (meta?['name'] as String?) ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _otherRoleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _fmtDob(picked);
      });
    }
  }

  Future<void> _submit() async {
    final role = _role == 'Other' ? _otherRoleCtrl.text.trim() : _role;
    if (_nameCtrl.text.trim().isEmpty ||
        _companyCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        role.isEmpty ||
        _dob == null) {
      setState(() => _error = 'Please fill in every field');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await authService.updateProfile(
        name: _nameCtrl.text.trim(),
        dob: _dob!.toIso8601String(),
        company: _companyCtrl.text.trim(),
        role: role,
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = 'Could not save your profile. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDob(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final initial = (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : _email);
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 36, 26, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(gradient: AppColors.copperGradient, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initial.isNotEmpty ? initial[0].toUpperCase() : '?',
                        style: AppText.spaceGrotesk(size: 19, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete your profile', style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(_email, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Takes a minute — these details identify you on every visit and report you file.',
                  style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary, height: 1.55)),
              const SizedBox(height: 28),
              const _SectionHeader(icon: Icons.person_outline, label: 'PERSONAL'),
              const SizedBox(height: 14),
              AppTextField(label: 'Full name', hint: 'e.g. Riya Desai', controller: _nameCtrl),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickDob,
                child: AbsorbPointer(
                  child: AppTextField(label: 'Date of birth', hint: 'DD/MM/YYYY', controller: _dobCtrl, icon: Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 24),
              const _SectionHeader(icon: Icons.work_outline, label: 'WORK'),
              const SizedBox(height: 14),
              AppTextField(label: 'Company / Organisation', hint: 'e.g. Tata Steel CSR', controller: _companyCtrl),
              const SizedBox(height: 14),
              Text('ROLE', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((r) => GestureDetector(
                      onTap: () => setState(() => _role = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _role == r ? AppColors.copperMid : AppColors.bgCard,
                          border: Border.all(color: _role == r ? AppColors.copperMid : AppColors.borderSubtle),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_role == r) ...[
                              const Icon(Icons.check, size: 13, color: Colors.white),
                              const SizedBox(width: 5),
                            ],
                            Text(r, style: AppText.spaceGrotesk(
                              size: 12, weight: FontWeight.w600,
                              color: _role == r ? Colors.white : AppColors.textSecondary,
                            )),
                          ],
                        ),
                      ),
                    )).toList(),
              ),
              if (_role == 'Other') ...[
                const SizedBox(height: 14),
                AppTextField(label: 'Your designation', hint: 'e.g. Program Manager', controller: _otherRoleCtrl),
              ],
              const SizedBox(height: 14),
              AppTextField(label: 'Contact number', hint: '+91 98765 43210', controller: _phoneCtrl,
                  keyboardType: TextInputType.phone, icon: Icons.phone_outlined),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.08),
                    border: Border.all(color: AppColors.red.withOpacity(0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: AppText.spaceGrotesk(size: 12, color: AppColors.red)),
                ),
              ],
              const SizedBox(height: 26),
              CopperButton(label: _saving ? 'Saving…' : 'Save & Continue', onTap: _saving ? () {} : _submit),
              const SizedBox(height: 16),
              Center(
                child: Text('Kept private — only shown on reports you share.',
                    style: AppText.spaceGrotesk(size: 11, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.copperMid),
          const SizedBox(width: 8),
          Text(label, style: AppText.spaceGrotesk(size: 11, weight: FontWeight.w700, color: AppColors.copperMid, letterSpacing: 1)),
        ],
      );
}
