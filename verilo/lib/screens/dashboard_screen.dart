import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

const _reviewsPerInterval = {'Monthly': 12, 'Quarterly': 4, 'Biannual': 2, 'Annual': 1};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  bool _mapView = false;
  int _navIndex = 0;
  List<Project> _projects = [];
  Map<int, List<Visit>> _visitsByProject = {};
  bool _loading = true;

  late final AnimationController _pingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  late final AnimationController _ping2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
    ..forward()
    ..repeat();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await appRepository.allProjects();
    final visits = await appRepository.allMyVisits();
    final byProject = <int, List<Visit>>{};
    for (final v in visits) {
      byProject.putIfAbsent(v.projectId, () => []).add(v);
    }
    if (!mounted) return;
    setState(() { _projects = projects; _visitsByProject = byProject; _loading = false; });
  }

  @override
  void dispose() { _pingCtrl.dispose(); _ping2Ctrl.dispose(); super.dispose(); }

  int get _visitsThisMonth {
    final now = DateTime.now();
    return _visitsByProject.values.expand((v) => v).where((v) => v.startedAt.year == now.year && v.startedAt.month == now.month).length;
  }

  int get _reportsPending => _visitsByProject.values.expand((v) => v).where((v) => v.status == 'active').length;

  int get _activeProjects => _projects.where((p) => p.status == 'Active').length;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.copperMid))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32),
                            _Header(name: currentOfficerName),
                            const SizedBox(height: 16),
                            _StatsRow(visits: _visitsThisMonth, pending: _reportsPending, active: _activeProjects),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Text('Projects', style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w600)),
                                const Spacer(),
                                _ViewToggle(isMap: _mapView, onToggle: (v) => setState(() => _mapView = v)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_projects.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text('No projects yet. Tap "New Project" to add your first site.',
                                      style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
                                ),
                              )
                            else if (!_mapView)
                              ..._projects.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ProjectCard(
                                      project: p,
                                      visits: _visitsByProject[p.id] ?? const [],
                                      onTap: () => context.go('/project/${p.id}'),
                                    ),
                                  ))
                            else
                              _MapView(
                                projects: _projects,
                                pingCtrl: _pingCtrl,
                                ping2Ctrl: _ping2Ctrl,
                                onProjectTap: (id) => context.go('/project/$id'),
                              ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
            ),
            BottomNav(currentIndex: _navIndex, onTap: (i) {
              if (i == 3) {
                context.push('/profile-setup');
                return;
              }
              // ponytail: Home/Projects share this screen; Map = the map view
              setState(() { _navIndex = i; _mapView = i == 2; });
            }),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/create-project').then((_) => _load()),
            backgroundColor: AppColors.copperMid,
            elevation: 8,
            label: Text('New Project', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w700, color: Colors.white)),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(name, style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
          ]),
          const Spacer(),
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(gradient: AppColors.copperGradient, shape: BoxShape.circle),
            child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppText.spaceGrotesk(size: 15, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.visits, required this.pending, required this.active});
  final int visits, pending, active;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatCard(value: '$visits', label: 'Visits\nthis month', color: AppColors.copperLight),
          const SizedBox(width: 8),
          _StatCard(value: '$pending', label: 'Reports\npending', color: AppColors.amber),
          const SizedBox(width: 8),
          _StatCard(value: '$active', label: 'Active\nprojects', color: AppColors.textPrimary),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: CardSurface(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Text(value, style: AppText.spaceGrotesk(size: 22, weight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label, style: AppText.spaceGrotesk(size: 10, color: AppColors.textSecondary, height: 1.3), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isMap, required this.onToggle});
  final bool isMap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: const Color(0xFF332F2A), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            _ToggleBtn(label: 'List', active: !isMap, onTap: () => onToggle(false)),
            _ToggleBtn(label: 'Map', active: isMap, onTap: () => onToggle(true)),
          ],
        ),
      );
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.copperMid : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(label, style: AppText.spaceGrotesk(
            size: 11, weight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF476058),
          )),
        ),
      );
}

Color _categoryColor(String category) => category.toLowerCase().contains('skill') ? AppColors.blue : AppColors.copperMid;
Color _statusColor(String status) => status == 'Active' ? AppColors.blue : AppColors.amber;

String _relativeTime(DateTime? dt) {
  if (dt == null) return 'never';
  final d = DateTime.now().difference(dt);
  if (d.inDays >= 7) return '${(d.inDays / 7).floor()}w ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  return 'just now';
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.visits, required this.onTap});
  final Project project;
  final List<Visit> visits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(project.category);
    final statusColor = _statusColor(project.status);
    final total = _reviewsPerInterval[project.reviewInterval] ?? 4;
    final completed = visits.where((v) => v.status == 'complete').length;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final lastVisit = visits.isEmpty
        ? null
        : visits.map((v) => v.startedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final tags = project.sdgTags.split(',').where((t) => t.isNotEmpty).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 76,
                  decoration: BoxDecoration(color: AppColors.bgPlaceholder, borderRadius: BorderRadius.circular(10)),
                ),
                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      border: Border.all(color: categoryColor.withOpacity(0.18)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(project.category.toUpperCase(), style: AppText.spaceGrotesk(size: 9, weight: FontWeight.w600, color: categoryColor)),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Text('Last visit: ${_relativeTime(lastVisit)}', style: AppText.spaceGrotesk(size: 9, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(project.name, style: AppText.spaceGrotesk(size: 15, weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text([project.district, project.state].where((s) => s.isNotEmpty).join(', '),
                style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                ...tags.map((t) => Padding(padding: const EdgeInsets.only(right: 6), child: StatusChip(label: t, color: categoryColor))),
                const Spacer(),
                StatusChip(label: project.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 4, color: const Color(0xFF332F2A),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(color: statusColor == AppColors.blue ? AppColors.copperLight : AppColors.amber),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$completed / $total', style: AppText.spaceGrotesk(size: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.projects, required this.pingCtrl, required this.ping2Ctrl, required this.onProjectTap});
  final List<Project> projects;
  final AnimationController pingCtrl, ping2Ctrl;
  final ValueChanged<int> onProjectTap;

  @override
  Widget build(BuildContext context) {
    final located = projects.where((p) => p.lat != null && p.lng != null).toList();
    return Container(
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            height: 230,
            decoration: const BoxDecoration(color: Color(0xFF2A2218), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                for (var i = 0; i < located.length; i++)
                  Positioned(
                    left: 40.0 + (i * 37) % 200,
                    top: 60.0 + (i * 53) % 130,
                    child: _MapPin(
                      ctrl: i.isEven ? pingCtrl : ping2Ctrl,
                      label: located[i].name,
                      sub: '${located[i].district} · ${located[i].status}',
                      color: _statusColor(located[i].status),
                      onTap: () => onProjectTap(located[i].id),
                    ),
                  ),
                if (located.isEmpty)
                  Center(child: Text('No project locations yet', style: AppText.spaceGrotesk(size: 12, color: Colors.white38))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${located.length} PROJECTS LOCATED', style: AppText.label),
                const SizedBox(height: 8),
                ...projects.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _LocationRow(
                        color: _statusColor(p.status),
                        name: p.name,
                        coords: p.lat != null ? '${p.lat!.toStringAsFixed(4)}°N ${p.lng!.toStringAsFixed(4)}°E' : 'No GPS set',
                        onTap: () => onProjectTap(p.id),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.ctrl, required this.label, required this.sub, required this.color, required this.onTap});
  final AnimationController ctrl;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -3 * (0.5 - (ctrl.value - 0.5).abs()) * 2),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppText.spaceGrotesk(size: 10, weight: FontWeight.w600, color: Colors.white)),
                  Text(sub, style: AppText.spaceGrotesk(size: 9, color: Colors.white70)),
                ]),
              ),
            ),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
          ],
        ),
      );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.color, required this.name, required this.coords, required this.onTap});
  final Color color;
  final String name, coords;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.bgApp, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                  Text(coords, style: AppText.jetBrainsMono(size: 11, color: AppColors.textSecondary)),
                ],
              )),
              Text('›', style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
