import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  static const _pages = [
    _OBPage(
      title: 'Evidence that holds up',
      body: 'Geo-tag every photo at the moment of capture. GPS accuracy, timestamp, and device signature — sealed at source.',
      illustration: _GPSIllustration(),
    ),
    _OBPage(
      title: 'Voice to verified report',
      body: 'Record voice notes on site. Clips attach to your visit alongside photos and checklists, and land in the final PDF report.',
      illustration: _WaveformIllustration(),
    ),
    _OBPage(
      title: 'Your data, your account',
      body: 'Visits sync to your private workspace — no one else can see your projects. Reports stay on your device until you share them.',
      illustration: _ShieldIllustration(),
    ),
  ];

  Future<void> _finish() async {
    (await SharedPreferences.getInstance()).setBool('seen_onboarding', true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_page < 2) {
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14, right: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text('Skip', style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _pages[_page],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        height: 5,
                        width: i == _page ? 22 : 6,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.copperMid : Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                    const SizedBox(height: 14),
                    CopperButton(
                      label: _page < 2 ? 'Next →' : 'Get Started →',
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _OBPage extends StatelessWidget {
  const _OBPage({required this.title, required this.body, required this.illustration});
  final String title;
  final String body;
  final Widget illustration;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 282,
              color: AppColors.bgPlaceholder,
              child: Center(child: illustration),
            ),
          ),
          const SizedBox(height: 24),
          Text(title, style: AppText.spaceGrotesk(size: 23, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: AppText.spaceGrotesk(size: 14, color: AppColors.textSecondary, height: 1.7)),
        ],
      );
}

class _GPSIllustration extends StatelessWidget {
  const _GPSIllustration();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(80, 80),
        painter: _GPSPainter(),
      );
}

class _GPSPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final stroke = Paint()..style = PaintingStyle.stroke;

    stroke.color = AppColors.copperMid.withOpacity(0.2);
    stroke.strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), 32, stroke);

    stroke.color = AppColors.copperMid.withOpacity(0.4);
    stroke.strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 20, stroke);

    canvas.drawCircle(Offset(cx, cy), 9, Paint()..color = AppColors.copperLight.withOpacity(0.9));

    stroke.color = AppColors.copperMid.withOpacity(0.15);
    stroke.strokeWidth = 1;
    canvas.drawLine(Offset(cx, 4), Offset(cx, 76), stroke);
    canvas.drawLine(Offset(4, cy), Offset(76, cy), stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _WaveformIllustration extends StatefulWidget {
  const _WaveformIllustration();

  @override
  State<_WaveformIllustration> createState() => _WaveformIllustrationState();
}

class _WaveformIllustrationState extends State<_WaveformIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  static const _heights = [5.0, 14.0, 9.0, 20.0, 5.0, 28.0, 9.0, 36.0, 14.0];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_heights.length, (i) {
            final t = ((_ctrl.value + i * 0.08) % 1.0);
            final h = 5.0 + (_heights[i] - 5.0) * (0.5 - (t - 0.5).abs()) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: h.clamp(5.0, 36.0),
              decoration: BoxDecoration(color: AppColors.copperLight, borderRadius: BorderRadius.circular(2)),
            );
          }),
        ),
      );
}

class _ShieldIllustration extends StatelessWidget {
  const _ShieldIllustration();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(62, 70),
        painter: _ShieldPainter(),
      );
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(31, 2)
      ..lineTo(60, 14)
      ..lineTo(60, 38)
      ..quadraticBezierTo(60, 56, 31, 68)
      ..quadraticBezierTo(2, 56, 2, 38)
      ..lineTo(2, 14)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.copperMid.withOpacity(0.06));
    canvas.drawPath(path, Paint()..color = AppColors.copperMid..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final check = Path()
      ..moveTo(19, 35)
      ..lineTo(27, 43)
      ..lineTo(43, 27);
    canvas.drawPath(check, Paint()
      ..color = AppColors.copperLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_) => false;
}
