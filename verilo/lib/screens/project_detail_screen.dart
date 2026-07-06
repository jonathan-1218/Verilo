import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Project? _project;
  List<Visit> _visits = [];
  bool _loading = true;
  bool _startingVisit = false;

  int get _projectId => int.parse(widget.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final project = await appRepository.projectById(_projectId);
    final visits = await appRepository.visitsForProject(_projectId);
    if (!mounted) return;
    setState(() { _project = project; _visits = visits.reversed.toList(); _loading = false; });
  }

  Future<void> _startVisit() async {
    setState(() => _startingVisit = true);
    try {
      // warms up GPS/permission before /visit-setup; a timeout here must not
      // block the visit — the setup screen does its own GPS acquisition
      await locationService.currentPosition();
    } catch (_) {} finally {
      if (mounted) setState(() => _startingVisit = false);
    }
    if (mounted) context.push('/visit-setup?projectId=$_projectId').then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bgApp, body: Center(child: CircularProgressIndicator(color: AppColors.copperMid)));
    }
    final project = _project;
    if (project == null) {
      return Scaffold(
        backgroundColor: AppColors.bgApp,
        body: Center(child: Text('Project not found', style: AppText.spaceGrotesk(size: 14, color: AppColors.textMuted))),
      );
    }
    final tags = project.sdgTags.split(',').where((t) => t.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          SafeArea(
            child: _Header(
              title: project.name,
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
              onInfo: () => context.push('/project/${widget.id}/params'),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ...tags.map((t) => StatusChip(label: t, color: AppColors.copperMid)),
                      StatusChip(label: project.status, color: project.status == 'Active' ? AppColors.blue : AppColors.amber),
                      StatusChip(label: project.category.toUpperCase(), color: AppColors.textMuted),
                    ]),
                    const SizedBox(height: 14),
                    CardSurface(
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('BUDGET', style: AppText.label),
                          const SizedBox(height: 4),
                          Text('₹${(project.budgetCents / 100).round()}', style: AppText.spaceGrotesk(size: 16, weight: FontWeight.w700)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('PERIOD', style: AppText.label),
                          const SizedBox(height: 4),
                          Text(_periodLabel(project), style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text('VISIT HISTORY', style: AppText.label),
                    const SizedBox(height: 10),
                    if (_visits.isEmpty)
                      CardSurface(child: Text('No visits yet. Tap "Start Visit" to begin the first one.',
                          style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted)))
                    else
                      ..._visits.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _VisitRow(visit: v, onTap: v.status == 'complete'
                                ? () => context.push('/report?visitId=${v.id}')
                                : () => context.push('/visit-capture?visitId=${v.id}').then((_) => _load())),
                          )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: FloatingActionButton.extended(
          onPressed: _startingVisit ? null : _startVisit,
          backgroundColor: AppColors.copperMid,
          label: Text(_startingVisit ? 'Locating…' : 'Start Visit', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w700, color: Colors.white)),
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        ),
      ),
    );
  }

  String _periodLabel(Project p) {
    if (p.startDate == null) return '—';
    final start = '${_month(p.startDate!.month)} ${p.startDate!.year}';
    final end = p.endDate == null ? 'ongoing' : '${_month(p.endDate!.month)} ${p.endDate!.year}';
    return '$start – $end';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _month(int m) => _months[m - 1];
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, required this.onInfo});
  final String title;
  final VoidCallback onBack, onInfo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppText.screenTitle, overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: onInfo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCardElevated,
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.copperMid),
                    const SizedBox(width: 4),
                    Text('Info', style: AppText.spaceGrotesk(size: 12, color: AppColors.copperMid)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.onTap});
  final Visit visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = visit.status == 'complete';
    return GestureDetector(
      onTap: onTap,
      child: CardSurface(
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (complete ? const Color(0xFF13BA78) : AppColors.copperMid).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(complete ? Icons.check : Icons.play_arrow_rounded, size: 16, color: complete ? const Color(0xFF13BA78) : AppColors.copperMid),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${visit.startedAt.day}/${visit.startedAt.month}/${visit.startedAt.year} · ${visit.officerName}',
                    style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                Text(complete ? 'Report ready' : 'In progress', style: AppText.spaceGrotesk(size: 11, color: AppColors.textSecondary)),
              ],
            )),
            StatusChip(label: complete ? 'Complete' : 'Active', color: complete ? const Color(0xFF13BA78) : AppColors.copperMid),
          ],
        ),
      ),
    );
  }
}
