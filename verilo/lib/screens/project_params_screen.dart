import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

class ProjectParamsScreen extends StatefulWidget {
  const ProjectParamsScreen({super.key, required this.id});
  final String id;

  @override
  State<ProjectParamsScreen> createState() => _ProjectParamsScreenState();
}

class _ProjectParamsScreenState extends State<ProjectParamsScreen> {
  Project? _project;

  @override
  void initState() {
    super.initState();
    appRepository.projectById(int.parse(widget.id)).then((p) {
      if (mounted) setState(() => _project = p);
    });
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day} ${_months[d.month - 1]} ${d.year}';
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final project = _project;
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Project Parameters', style: AppText.screenTitle),
                      Text(project?.name ?? '…', style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: project == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.copperMid))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      child: Column(
                        children: [
                          _ParamSection(
                            icon: Icons.calendar_today,
                            label: 'TIMELINE',
                            rows: [
                              ('Start date', _fmtDate(project.startDate)),
                              ('End date', _fmtDate(project.endDate)),
                              ('Review interval', project.reviewInterval),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ParamSection(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'BUDGET',
                            rows: [('Total budget', '₹${(project.budgetCents / 100).round()}')],
                          ),
                          const SizedBox(height: 12),
                          _ParamSection(
                            icon: Icons.location_on_outlined,
                            label: 'LOCATION',
                            rows: [
                              ('Site name', project.location),
                              ('District', project.district),
                              ('State', project.state),
                              ('Geofence', '${project.geofenceMeters.round()} m'),
                              ('GPS', project.lat != null ? '${project.lat!.toStringAsFixed(4)}°N ${project.lng!.toStringAsFixed(4)}°E' : 'Not set'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ParamSection(
                            icon: Icons.category_outlined,
                            label: 'INTERVENTION',
                            rows: [
                              ('Category', project.category),
                              ('SDG tags', project.sdgTags.isEmpty ? '—' : project.sdgTags.replaceAll(',', ', ')),
                              ('Beneficiaries', project.beneficiaries > 0 ? '${project.beneficiaries}' : '—'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ParamSection(
                            icon: Icons.handshake_outlined,
                            label: 'IMPLEMENTATION',
                            rows: [
                              ('Mode', project.implementingAgency.isEmpty ? 'Direct' : 'Implementing agency'),
                              ('Agency', project.implementingAgency.isEmpty ? '—' : project.implementingAgency),
                              ('CSR reg. no.', project.csrRegistrationNo.isEmpty ? '—' : project.csrRegistrationNo),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const _TeamSection(),
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

class _ParamSection extends StatelessWidget {
  const _ParamSection({required this.icon, required this.label, required this.rows});
  final IconData icon;
  final String label;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: AppColors.copperMid),
                  const SizedBox(width: 8),
                  Text(label, style: AppText.spaceGrotesk(size: 11, weight: FontWeight.w700, color: AppColors.copperMid, letterSpacing: 1)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(r.$1, style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
                      const Spacer(),
                      Flexible(child: Text(r.$2, textAlign: TextAlign.right, style: AppText.spaceGrotesk(size: 12, weight: FontWeight.w600))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      );
}

class _TeamSection extends StatelessWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.group_outlined, size: 14, color: AppColors.copperMid),
                  const SizedBox(width: 8),
                  Text('TEAM', style: AppText.spaceGrotesk(size: 11, weight: FontWeight.w700, color: AppColors.copperMid, letterSpacing: 1)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(gradient: AppColors.copperGradient, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(currentOfficerName.isNotEmpty ? currentOfficerName[0].toUpperCase() : '?',
                        style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(currentOfficerName, style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600))),
                  StatusChip(label: 'YOU', color: AppColors.copperMid),
                ],
              ),
            ),
          ],
        ),
      );
}
