import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/project_card.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// The Home tab: today's work. Stats, what needs attention (open visits,
/// overdue reviews), and the latest sealed reports. The full portfolio lives
/// on the Projects tab; the map on the Map tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Project> _projects = [];
  Map<int, List<Visit>> _visitsByProject = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // outbox replay is kicked fire-and-forget inside the repository reads
    final (projects, visits) = await (appRepository.allProjects(), appRepository.allMyVisits()).wait;
    final byProject = <int, List<Visit>>{};
    for (final v in visits) {
      byProject.putIfAbsent(v.projectId, () => []).add(v);
    }
    if (!mounted) return;
    setState(() { _projects = projects; _visitsByProject = byProject; _loading = false; });
  }

  Iterable<Visit> get _allVisits => _visitsByProject.values.expand((v) => v);

  int get _visitsThisMonth {
    final now = DateTime.now();
    return _allVisits.where((v) => v.startedAt.year == now.year && v.startedAt.month == now.month).length;
  }

  int get _reportsPending => _allVisits.where((v) => v.status == 'active').length;

  int get _activeProjects => _projects.where((p) => p.status == 'Active').length;

  Project? _projectFor(int id) => _projects.where((p) => p.id == id).firstOrNull;

  /// Visits still open (started, never ended) — resume these first.
  List<(Visit, Project)> get _openVisits {
    final open = [
      for (final v in _allVisits)
        if (v.status == 'active' && _projectFor(v.projectId) != null) (v, _projectFor(v.projectId)!),
    ];
    open.sort((a, b) => b.$1.startedAt.compareTo(a.$1.startedAt));
    return open;
  }

  /// Active projects whose last completed visit is older than their review
  /// interval allows (or that have never been visited).
  List<(Project, DateTime?)> get _overdueProjects {
    final now = DateTime.now();
    final result = <(Project, DateTime?)>[];
    for (final p in _projects.where((p) => p.status == 'Active')) {
      final completed = (_visitsByProject[p.id] ?? const <Visit>[]).where((v) => v.status == 'complete');
      final last = completed.isEmpty
          ? null
          : completed.map((v) => v.startedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      final perYear = kReviewsPerInterval[p.reviewInterval] ?? 4;
      final dueDays = 365 ~/ perYear;
      if (now.difference(last ?? p.createdAt).inDays > dueDays) result.add((p, last));
    }
    return result;
  }

  /// Latest completed visits, newest first.
  List<(Visit, Project)> get _recentReports {
    final done = [
      for (final v in _allVisits)
        if (v.status == 'complete' && _projectFor(v.projectId) != null) (v, _projectFor(v.projectId)!),
    ];
    done.sort((a, b) => (b.$1.endedAt ?? b.$1.startedAt).compareTo(a.$1.endedAt ?? a.$1.startedAt));
    return done.take(3).toList();
  }

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
                            const SizedBox(height: 20),
                            Text('NEEDS ATTENTION', style: AppText.label),
                            const SizedBox(height: 8),
                            if (_openVisits.isEmpty && _overdueProjects.isEmpty)
                              const _AttentionRow(
                                icon: Icons.check_circle_outline,
                                color: AppColors.copperMid,
                                title: 'All caught up',
                                subtitle: 'No open visits or overdue reviews',
                              )
                            else ...[
                              ..._openVisits.map((e) => _AttentionRow(
                                    icon: Icons.play_circle_outline,
                                    color: AppColors.blue,
                                    title: e.$2.name,
                                    subtitle: 'Visit in progress · started ${relativeTime(e.$1.startedAt)}',
                                    onTap: () => context.push('/visit-capture?visitId=${e.$1.id}').then((_) => _load()),
                                  )),
                              ..._overdueProjects.map((e) => _AttentionRow(
                                    icon: Icons.event_repeat,
                                    color: AppColors.amber,
                                    title: e.$1.name,
                                    subtitle: e.$2 == null
                                        ? '${e.$1.reviewInterval} review due · never visited'
                                        : '${e.$1.reviewInterval} review due · last visit ${relativeTime(e.$2)}',
                                    onTap: () => context.push('/visit-setup?projectId=${e.$1.id}').then((_) => _load()),
                                  )),
                            ],
                            if (_recentReports.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text('RECENT REPORTS', style: AppText.label),
                              const SizedBox(height: 8),
                              ..._recentReports.map((e) => _AttentionRow(
                                    icon: Icons.description_outlined,
                                    color: AppColors.copperLight,
                                    title: e.$2.name,
                                    subtitle: e.$1.reportHash != null
                                        ? 'Sealed report · ${relativeTime(e.$1.endedAt ?? e.$1.startedAt)}'
                                        : 'Completed · ${relativeTime(e.$1.endedAt ?? e.$1.startedAt)}',
                                    onTap: () => context.push('/report?visitId=${e.$1.id}').then((_) => _load()),
                                  )),
                            ],
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
            BottomNav(currentIndex: 0, onTap: (i) {
              switch (i) {
                case 1: context.go('/projects');
                case 2: context.go('/map');
                case 3: context.go('/profile');
              }
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
  Widget build(BuildContext context) {
    final avatarUrl = authService.avatarUrl;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(name, style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(gradient: AppColors.copperGradient, shape: BoxShape.circle),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(avatarUrl, width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(initial,
                                style: AppText.spaceGrotesk(size: 15, weight: FontWeight.w700, color: Colors.white)))))
                : Center(
                    child: Text(initial,
                        style: AppText.spaceGrotesk(size: 15, weight: FontWeight.w700, color: Colors.white))),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.visits, required this.pending, required this.active});
  final int visits, pending, active;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatCard(value: '$visits', label: 'Visits\nthis month', color: AppColors.copperLight),
          const SizedBox(width: 8),
          _StatCard(value: '$pending', label: 'Visits\nopen', color: AppColors.amber),
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

/// One actionable row: colored icon, what it is, why it's here, chevron.
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.spaceGrotesk(size: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}
