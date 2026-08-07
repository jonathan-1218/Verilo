import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/project_card.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// The Projects tab: every project as a card, under a portfolio header —
/// stat tiles plus a category breakdown bar.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  Map<int, List<Visit>> _visitsByProject = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (projects, visits) = await (appRepository.allProjects(), appRepository.allMyVisits()).wait;
    final byProject = <int, List<Visit>>{};
    for (final v in visits) {
      byProject.putIfAbsent(v.projectId, () => []).add(v);
    }
    // active projects first, then by name — the list is a worklist
    projects.sort((a, b) {
      if (a.status != b.status) return a.status == 'Active' ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    if (!mounted) return;
    setState(() { _projects = projects; _visitsByProject = byProject; _loading = false; });
  }

  int get _activeCount => _projects.where((p) => p.status == 'Active').length;

  int get _totalBudgetCents => _projects.fold(0, (sum, p) => sum + p.budgetCents);

  String get _budgetLabel {
    final rupees = _totalBudgetCents / 100;
    if (rupees >= 1e7) return '₹${(rupees / 1e7).toStringAsFixed(1)}Cr';
    if (rupees >= 1e5) return '₹${(rupees / 1e5).toStringAsFixed(1)}L';
    return '₹${rupees.round()}';
  }

  /// Counts per category in the fixed categorical order (absent ones skipped).
  List<(String, int)> get _categoryCounts {
    final counts = <String, int>{};
    for (final p in _projects) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final known = [
      for (final c in kCategoryOrder)
        if (counts.containsKey(c)) (c, counts[c]!),
    ];
    final other = _projects.length - known.fold<int>(0, (s, e) => s + e.$2);
    return [...known, if (other > 0) ('Other', other)];
  }

  @override
  Widget build(BuildContext context) => TabBackScope(
      child: Scaffold(
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
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32),
                            Text('Projects', style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('Your full portfolio, active work first',
                                style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _StatTile(value: '${_projects.length}', label: 'Projects'),
                                const SizedBox(width: 8),
                                _StatTile(value: '$_activeCount', label: 'Active', color: AppColors.blue),
                                const SizedBox(width: 8),
                                _StatTile(value: _budgetLabel, label: 'Total budget', color: AppColors.copperLight),
                              ],
                            ),
                            if (_projects.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _CategoryBreakdown(counts: _categoryCounts),
                            ],
                            const SizedBox(height: 20),
                            if (_projects.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: Text('No projects yet. Create one from the Home tab.',
                                      style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted),
                                      textAlign: TextAlign.center),
                                ),
                              )
                            else
                              ..._projects.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ProjectCard(
                                      project: p,
                                      visits: _visitsByProject[p.id] ?? const [],
                                      onTap: () => context.push('/project/${p.id}').then((_) => _load()),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ),
            ),
            BottomNav(currentIndex: 1, onTap: (i) {
              if (i == 1) return;
              context.go(switch (i) { 0 => '/dashboard', 2 => '/map', _ => '/profile' });
            }),
          ],
        ),
      ));
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.color = AppColors.textPrimary});
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
              Text(label, textAlign: TextAlign.center,
                  style: AppText.spaceGrotesk(size: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

/// One stacked bar of project counts by category, with a count-labelled
/// legend beneath (identity is never carried by color alone).
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.counts});
  final List<(String, int)> counts;

  @override
  Widget build(BuildContext context) => CardSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BY CATEGORY', style: AppText.label),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  for (final (i, entry) in counts.indexed) ...[
                    if (i > 0) const SizedBox(width: 2), // surface gap between fills
                    Expanded(
                      flex: entry.$2,
                      child: Container(height: 10, color: categoryColor(entry.$1)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (cat, n) in counts)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: categoryColor(cat), borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 5),
                      Text('$cat  $n', style: AppText.spaceGrotesk(size: 11, color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
}
