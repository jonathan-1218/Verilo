import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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
  List<Photo> _photos = [];
  List<VoiceClip> _clips = [];
  bool _loading = true;
  bool _startingVisit = false;

  int get _projectId => int.parse(widget.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (project, visits, photos, clips) = await (
      appRepository.projectById(_projectId),
      appRepository.visitsForProject(_projectId),
      appRepository.photosForProject(_projectId),
      appRepository.clipsForProject(_projectId),
    ).wait;
    if (!mounted) return;
    setState(() {
      _project = project;
      _visits = visits.reversed.toList();
      _photos = photos;
      _clips = clips;
      _loading = false;
    });
  }

  /// Saves one media file wherever the user picks (system save dialog).
  /// Works for local captures and, when the local file is gone, the synced
  /// cloud copy.
  Future<void> _download({required String filePath, String? storagePath, required String name}) async {
    final bytes = await appRepository.mediaBytes(filePath: filePath, storagePath: storagePath);
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File unavailable — not on this device and not synced yet.')));
      return;
    }
    final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(data: bytes, fileName: name));
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $name')));
    }
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
                    // Fixed 2×2 grid so the card holds the same shape whether or
                    // not the fields were filled in at creation time.
                    CardSurface(
                      child: Column(children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _Field(label: 'BUDGET', value: project.budgetCents > 0 ? '₹${(project.budgetCents / 100).round()}' : null, emphasis: true)),
                          Expanded(child: _Field(label: 'PERIOD', value: _periodLabel(project))),
                        ]),
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _Field(label: 'BENEFICIARIES', value: project.beneficiaries > 0 ? '${project.beneficiaries}' : null, emphasis: true)),
                          Expanded(child: _Field(
                            label: 'IMPLEMENTED BY',
                            value: project.implementingAgency.isNotEmpty ? project.implementingAgency : 'Direct',
                          )),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text('MEDIA', style: AppText.label),
                    const SizedBox(height: 10),
                    if (_photos.isEmpty && _clips.isEmpty)
                      CardSurface(
                          child: Text('Photos and voice notes from visits appear here.',
                              style: AppText.spaceGrotesk(size: 13, color: AppColors.textMuted)))
                    else ...[
                      if (_photos.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in _photos)
                              _PhotoThumb(
                                photo: p,
                                onDownload: () => _download(
                                    filePath: p.filePath,
                                    storagePath: p.storagePath,
                                    name: 'verilo_photo_${p.id}.jpg'),
                              ),
                          ],
                        ),
                      if (_clips.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final c in _clips)
                          _MediaClipRow(
                            clip: c,
                            onDownload: () => _download(
                                filePath: c.filePath,
                                storagePath: c.storagePath,
                                name:
                                    'verilo_clip_${c.id}.${c.filePath.endsWith('.wav') ? 'wav' : 'm4a'}'),
                          ),
                      ],
                    ],
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

  String? _periodLabel(Project p) {
    if (p.startDate == null) return null;
    final start = '${_month(p.startDate!.month)} ${p.startDate!.year}';
    final end = p.endDate == null ? 'ongoing' : '${_month(p.endDate!.month)} ${p.endDate!.year}';
    return '$start – $end';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _month(int m) => _months[m - 1];
}

/// Label above value, with a muted placeholder when the value is missing, so
/// an unfilled project still occupies the same space as a filled one.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String? value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 4),
          Text(
            value ?? 'Not set',
            style: value == null
                ? AppText.spaceGrotesk(size: 13, color: AppColors.textMuted)
                : AppText.spaceGrotesk(
                    size: emphasis ? 16 : 13,
                    weight: emphasis ? FontWeight.w700 : FontWeight.w400,
                    color: emphasis ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
          ),
        ],
      );
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

/// 96px thumbnail with a download button. Local file renders; a cloud-only
/// photo (viewed from another device) shows a placeholder but still downloads.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onDownload});
  final Photo photo;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final file = File(photo.filePath);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: file.existsSync()
              ? Image.file(file, width: 96, height: 96, fit: BoxFit.cover)
              : Container(
                  width: 96, height: 96,
                  color: AppColors.bgPlaceholder,
                  child: const Icon(Icons.cloud_outlined, size: 22, color: AppColors.textMuted),
                ),
        ),
        Positioned(
          right: 4, bottom: 4,
          child: GestureDetector(
            onTap: onDownload,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: AppColors.bgDeep, shape: BoxShape.circle),
              child: const Icon(Icons.download, size: 13, color: AppColors.copperMid),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaClipRow extends StatelessWidget {
  const _MediaClipRow({required this.clip, required this.onDownload});
  final VoiceClip clip;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.mic, size: 16, color: AppColors.copperMid),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${clip.recordedAt.day}/${clip.recordedAt.month}/${clip.recordedAt.year} '
                '${clip.recordedAt.hour.toString().padLeft(2, '0')}:${clip.recordedAt.minute.toString().padLeft(2, '0')}'
                ' · 0:${clip.durationSeconds.toString().padLeft(2, '0')}',
                style: AppText.spaceGrotesk(size: 12),
              ),
            ),
            GestureDetector(
              onTap: onDownload,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.download, size: 18, color: AppColors.copperMid),
              ),
            ),
          ],
        ),
      );
}
