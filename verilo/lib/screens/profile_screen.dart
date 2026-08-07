import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// The Profile tab: read-only identity. Edits happen in Settings; the only
/// direct action here is changing the photo (and signing out).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarUrl;
  bool _avatarBusy = false;

  Map<String, dynamic> get _meta => authService.currentSession?.user.userMetadata ?? {};
  String get _email => authService.currentSession?.user.email ?? '';

  @override
  void initState() {
    super.initState();
    _avatarUrl = authService.avatarUrl;
  }

  String _field(String key) => (_meta[key] as String?) ?? '—';

  String get _dobLabel {
    final dob = DateTime.tryParse((_meta['dob'] as String?) ?? '');
    if (dob == null) return '—';
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
    if (picked == null) return;
    setState(() => _avatarBusy = true);
    try {
      final url = await authService.setAvatar(picked.path);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not upload the photo. Check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCardElevated,
        title: Text('Sign out?', style: AppText.spaceGrotesk(size: 16, weight: FontWeight.w700)),
        content: Text('You\'ll need a new email code or OAuth sign-in to get back in.',
            style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign out', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600, color: AppColors.red))),
        ],
      ),
    );
    // router's refreshListenable sees the auth change and returns to /login
    if (confirmed == true) await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final name = _field('name');
    final initial = name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?';
    return TabBackScope(
        child: Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _avatarBusy ? null : _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 64, height: 64,
                              decoration: const BoxDecoration(gradient: AppColors.copperGradient, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: _avatarBusy
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : _avatarUrl != null
                                      ? ClipOval(
                                          child: Image.network(_avatarUrl!,
                                              width: 64, height: 64, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Text(initial,
                                                  style: AppText.spaceGrotesk(size: 22, weight: FontWeight.w700, color: Colors.white))))
                                      : Text(initial,
                                          style: AppText.spaceGrotesk(size: 22, weight: FontWeight.w700, color: Colors.white)),
                            ),
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppColors.bgCardElevated, shape: BoxShape.circle),
                                child: const Icon(Icons.photo_camera, size: 12, color: AppColors.copperMid),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(_email, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/settings').then((_) => setState(() {})),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderSubtle),
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.bgCard,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.settings_outlined, size: 15, color: AppColors.textSecondary),
                                const SizedBox(width: 7),
                                Text('Settings', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/model-download'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderSubtle),
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.bgCard,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.download_outlined, size: 15, color: AppColors.textSecondary),
                                const SizedBox(width: 7),
                                Text('AI models', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('DETAILS', style: AppText.label),
                  const SizedBox(height: 8),
                  CardSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Full name', value: name),
                        _DetailRow(label: 'Date of birth', value: _dobLabel),
                        _DetailRow(label: 'Company', value: _field('company')),
                        _DetailRow(label: 'Role', value: _field('role')),
                        _DetailRow(label: 'Phone', value: _field('phone')),
                        _DetailRow(label: 'Email', value: _email, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: _signOut,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.logout, size: 15, color: AppColors.red),
                          const SizedBox(width: 7),
                          Text('Sign out', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600, color: AppColors.red)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomNav(currentIndex: 3, onTap: (i) {
            if (i == 3) return;
            context.go(switch (i) { 0 => '/dashboard', 1 => '/projects', _ => '/map' });
          }),
        ],
      ),
    ));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.last = false});
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last
            ? null
            : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w500))),
          ],
        ),
      );
}
