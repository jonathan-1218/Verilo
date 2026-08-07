import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

class VisitSetupScreen extends StatefulWidget {
  const VisitSetupScreen({super.key, required this.projectId});
  final int projectId;

  @override
  State<VisitSetupScreen> createState() => _VisitSetupScreenState();
}

class _VisitSetupScreenState extends State<VisitSetupScreen> with TickerProviderStateMixin {
  late final AnimationController _pingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  late final AnimationController _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  Project? _project;
  Position? _position;
  bool _locating = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    appRepository.projectById(widget.projectId).then((p) {
      if (mounted) setState(() => _project = p);
    });
    _acquireGps();
  }

  Future<void> _acquireGps() async {
    final pos = await locationService.currentPosition();
    if (!mounted) return;
    setState(() { _position = pos; _locating = false; });
  }

  double? get _distanceFromSite {
    final p = _project;
    final pos = _position;
    if (p?.lat == null || pos == null) return null;
    return locationService.distanceMeters(p!.lat!, p.lng!, pos.latitude, pos.longitude);
  }

  Future<void> _startVisit() async {
    setState(() => _starting = true);
    try {
      final visit = await appRepository.startVisit(
        projectId: widget.projectId,
        officerName: currentOfficerName,
        startLat: _position?.latitude,
        startLng: _position?.longitude,
        gpsAccuracyMeters: _position?.accuracy,
      );
      if (mounted) context.pushReplacement('/visit-capture?visitId=${visit.id}');
    } catch (_) {
      // ponytail: starting a visit needs connectivity (no offline outbox yet);
      // surface that instead of failing silently
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't start the visit. Check your internet connection and try again."),
        ));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() { _pingCtrl.dispose(); _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceFromSite;
    final geofence = _project?.geofenceMeters ?? 500;
    final outsideGeofence = distance != null && distance > geofence;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text('GPS Lock', style: AppText.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                child: Column(
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(color: const Color(0xFF2A2218), borderRadius: BorderRadius.circular(16)),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(size: const Size(double.infinity, 220), painter: _MapGridPainter()),
                          AnimatedBuilder(
                            animation: _pingCtrl,
                            builder: (_, __) => Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: 1 + _pingCtrl.value * 3,
                                  child: Opacity(
                                    opacity: (0.4 * (1 - _pingCtrl.value)).clamp(0, 1),
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _locating ? AppColors.amber : AppColors.copperMid, width: 1.5)),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    color: _locating ? AppColors.amber : AppColors.copperMid,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: (_locating ? AppColors.amber : AppColors.copperMid).withOpacity(0.5), blurRadius: 8)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CardSurface(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (_, __) => Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: (_locating ? AppColors.amber : const Color(0xFF13BA78)).withOpacity(0.5 + 0.5 * _pulseCtrl.value), shape: BoxShape.circle),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_locating ? 'GPS acquiring' : (_position == null ? 'GPS unavailable' : 'GPS locked'),
                                  style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(_position != null ? '±${_position!.accuracy.round()} m' : '—',
                                  style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600, color: AppColors.amber)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CopperProgressBar(value: _locating ? 0.4 : 1.0),
                          const SizedBox(height: 8),
                          Text('High-accuracy GPS · Fused provider', style: AppText.jetBrainsMono(size: 10)),
                        ],
                      ),
                    ),
                    if (outsideGeofence) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.amberBg, border: Border.all(color: AppColors.amber.withOpacity(0.15)), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_outlined, size: 16, color: AppColors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You are ${distance.round()} m from the registered project site. Visit data will still be captured but geofence compliance will be noted.',
                                style: AppText.spaceGrotesk(size: 12, color: AppColors.amber, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    CopperButton(label: _starting ? 'Starting…' : 'Start Visit Now', onTap: _starting ? () {} : _startVisit),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.borderSubtle), borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text('Cancel', style: AppText.spaceGrotesk(size: 14, color: AppColors.textMuted)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }

  @override
  bool shouldRepaint(_) => false;
}
