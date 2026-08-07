import 'package:flutter/material.dart';
import 'colors.dart';
import 'database.dart';
import 'text_styles.dart';
import 'widgets.dart';

/// Expected completed visits per year for each review interval.
const kReviewsPerInterval = {'Monthly': 12, 'Quarterly': 4, 'Biannual': 2, 'Annual': 1};

/// Fixed category order (mirrors the create-project chips) — categorical
/// colors are assigned by entity in this order, never cycled.
const kCategoryOrder = ['WASH', 'Education', 'Skill Dev', 'Health', 'Environment'];

// Categorical palette validated for the dark surface (lightness band, chroma
// floor, CVD separation, 3:1 contrast — dataviz six-checks validator).
const _categoryColors = {
  'WASH': Color(0xFF4E8FD9),
  'Education': Color(0xFFC97E45),
  'Skill Dev': Color(0xFF9B7BD1),
  'Health': Color(0xFFD46A88),
  'Environment': Color(0xFF26A3C2),
};

Color categoryColor(String category) => _categoryColors[category] ?? AppColors.copperMid;
Color statusColor(String status) => status == 'Active' ? AppColors.blue : AppColors.amber;

String relativeTime(DateTime? dt) {
  if (dt == null) return 'never';
  final d = DateTime.now().difference(dt);
  if (d.inDays >= 7) return '${(d.inDays / 7).floor()}w ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  return 'just now';
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.visits, required this.onTap});
  final Project project;
  final List<Visit> visits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(project.category);
    final stColor = statusColor(project.status);
    final total = kReviewsPerInterval[project.reviewInterval] ?? 4;
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
                      color: catColor.withValues(alpha: 0.1),
                      border: Border.all(color: catColor.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(project.category.toUpperCase(),
                        style: AppText.spaceGrotesk(size: 9, weight: FontWeight.w600, color: catColor)),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Text('Last visit: ${relativeTime(lastVisit)}',
                      style: AppText.spaceGrotesk(size: 9, color: AppColors.textSecondary)),
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
                ...tags.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: StatusChip(label: t, color: catColor))),
                const Spacer(),
                StatusChip(label: project.status, color: stColor),
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
                        child: Container(color: stColor == AppColors.blue ? AppColors.copperLight : AppColors.amber),
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
