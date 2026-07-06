import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _pingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final AnimationController _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _advance);
  }

  Future<void> _advance() async {
    final seen = (await SharedPreferences.getInstance()).getBool('seen_onboarding') ?? false;
    if (mounted) context.go(seen ? '/login' : '/onboarding');
  }

  @override
  void dispose() {
    _pingCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.splashGradient),
          child: Stack(
            children: [
              // subtle grid overlay
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter()),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fadeCtrl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(text: 'veri', style: AppText.spaceGrotesk(size: 50, weight: FontWeight.w700, color: AppColors.copperGlow, letterSpacing: -1.5)),
                          TextSpan(text: 'lo', style: AppText.spaceGrotesk(size: 50, weight: FontWeight.w700, color: Colors.white, letterSpacing: -1.5)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Text('EVERY VISIT. ON RECORD.',
                          style: AppText.spaceGrotesk(size: 11, color: Colors.white38, letterSpacing: 4)),
                      const SizedBox(height: 56),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pingCtrl,
                                  builder: (_, __) => Transform.scale(
                                    scale: 1 + _pingCtrl.value * 1.5,
                                    child: Opacity(
                                      opacity: (0.6 * (1 - _pingCtrl.value)).clamp(0, 1),
                                      child: Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: AppColors.copperGlow, shape: BoxShape.circle),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: AppColors.copperGlow, shape: BoxShape.circle),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Checking device setup…',
                              style: AppText.spaceGrotesk(size: 12, color: Colors.white38)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 32, left: 0, right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: _advance,
                    child: Text('Continue →',
                        style: AppText.spaceGrotesk(size: 13, color: Colors.white30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
