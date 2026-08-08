import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/repository.dart' show TranscriptState;
import '../core/text_styles.dart';
import '../core/widgets.dart';

class VisitCaptureScreen extends StatefulWidget {
  const VisitCaptureScreen({super.key, required this.visitId});
  final int visitId;

  @override
  State<VisitCaptureScreen> createState() => _VisitCaptureScreenState();
}

class _VisitCaptureScreenState extends State<VisitCaptureScreen> with TickerProviderStateMixin {
  int _tab = 0;
  bool _isTabbed = true;
  bool _isRecording = false;
  DateTime? _recordStart;
  Visit? _visit;
  Project? _project;
  List<Photo> _photos = [];
  List<VoiceClip> _clips = [];
  List<ChecklistItem> _checklist = [];
  final _notesCtrl = TextEditingController();
  Timer? _notesDebounce;
  bool _ending = false;
  final _player = AudioPlayer();
  int? _playingClipId;

  late final AnimationController _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..addListener(() { if (mounted) setState(() {}); })
    ..repeat();
  late final AnimationController _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  late final AnimationController _recordPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingClipId = null);
    });
    appRepository.transcriptionEvents.addListener(_onTranscriptionEvent);
  }

  Future<void> _onTranscriptionEvent() async {
    // queue state changed or a transcript landed — re-read the local rows
    final clips = await appRepository.clipsForVisit(widget.visitId);
    if (mounted) setState(() => _clips = clips);
  }

  Future<void> _deleteClip(VoiceClip clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCardElevated,
        title: Text('Delete recording?', style: AppText.spaceGrotesk(size: 16, weight: FontWeight.w700)),
        content: Text('The audio and its transcript are removed from this visit.',
            style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600, color: AppColors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_playingClipId == clip.id) {
      await _player.stop();
      _playingClipId = null;
    }
    await appRepository.deleteVoiceClip(clip);
    if (mounted) setState(() => _clips = _clips.where((c) => c.id != clip.id).toList());
  }

  Future<void> _togglePlay(VoiceClip clip) async {
    if (_playingClipId == clip.id) {
      await _player.stop();
      setState(() => _playingClipId = null);
      return;
    }
    await _player.stop();
    if (File(clip.filePath).existsSync()) {
      await _player.play(DeviceFileSource(clip.filePath));
    } else if (clip.storagePath != null) {
      // local file gone (e.g. clip recorded on another device) — stream it
      await _player.play(UrlSource(await appRepository.signedUrlFor(clip.storagePath!)));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording unavailable on this device')));
      }
      return;
    }
    setState(() => _playingClipId = clip.id);
  }

  Future<void> _load() async {
    final visit = await appRepository.visitById(widget.visitId);
    if (visit == null) {
      // no cached/remote copy of this visit — nothing to show, so bounce
      // back instead of spinning forever
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't load this visit.")));
        context.pop();
      }
      return;
    }
    final (project, photos, clips, checklist) = await (
      appRepository.projectById(visit.projectId),
      appRepository.photosForVisit(widget.visitId),
      appRepository.clipsForVisit(widget.visitId),
      appRepository.checklistForVisit(widget.visitId),
    ).wait;
    if (!mounted) return;
    setState(() {
      _visit = visit;
      _project = project;
      _photos = photos;
      _clips = clips;
      _checklist = checklist;
      _notesCtrl.text = visit.notes;
    });
  }

  @override
  void dispose() {
    appRepository.transcriptionEvents.removeListener(_onTranscriptionEvent);
    _timerCtrl.dispose();
    _waveCtrl.dispose();
    _recordPulse.dispose();
    _notesDebounce?.cancel();
    _notesCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final start = _visit?.startedAt;
    final secs = start == null ? 0 : DateTime.now().difference(start).inSeconds;
    final m = secs ~/ 60, s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _capturePhoto() async {
    final photo = await photoService.capturePhoto(widget.visitId);
    if (photo == null) return;
    await appRepository.syncPhoto(photo);
    if (!mounted) return;
    setState(() => _photos = [..._photos, photo]);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await audioService.stopRecording();
      final duration = _recordStart == null ? 0 : DateTime.now().difference(_recordStart!).inSeconds;
      setState(() => _isRecording = false);
      if (path != null) {
        final clip = await appRepository.saveVoiceClip(
            visitId: widget.visitId, filePath: path, durationSeconds: duration);
        if (mounted) setState(() => _clips = [..._clips, clip]);
      }
    } else {
      final started = await audioService.startRecording();
      if (!started) return;
      _recordStart = DateTime.now();
      setState(() => _isRecording = true);
    }
  }

  void _onNotesChanged(String text) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 800), () {
      final visit = _visit;
      if (visit != null) appRepository.updateVisitNotes(visit, text);
    });
  }

  Future<void> _toggleChecklist(ChecklistItem item) async {
    await appRepository.toggleChecklistItem(item);
    if (!mounted) return;
    setState(() {
      _checklist = _checklist.map((i) => i.id == item.id ? i.copyWith(completed: !i.completed) : i).toList();
    });
  }

  Future<void> _endVisit() async {
    final visit = _visit;
    if (visit == null) return;
    setState(() => _ending = true);
    await appRepository.endVisit(visit, notes: _notesCtrl.text);
    if (mounted) context.pushReplacement('/report?visitId=${widget.visitId}');
  }

  @override
  Widget build(BuildContext context) {
    if (_visit == null) {
      return const Scaffold(backgroundColor: AppColors.bgApp, body: Center(child: CircularProgressIndicator(color: AppColors.copperMid)));
    }
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            _CaptureHeader(
              projectName: _project?.name ?? '',
              timerLabel: _timerLabel,
              isTabbed: _isTabbed,
              busy: _ending,
              onToggleLayout: () => setState(() => _isTabbed = !_isTabbed),
              onEnd: _ending ? () {} : _endVisit,
            ),
            if (_isTabbed) _TabBar(activeTab: _tab, onTabChanged: (i) => setState(() => _tab = i)),
            Expanded(
              child: _isTabbed
                  ? _TabbedContent(
                      tab: _tab, isRecording: _isRecording,
                      waveCtrl: _waveCtrl, recordPulse: _recordPulse,
                      photos: _photos, clips: _clips, checklist: _checklist, notesCtrl: _notesCtrl,
                      playingClipId: _playingClipId, onPlayClip: _togglePlay, onDeleteClip: _deleteClip,
                      onCapturePhoto: _capturePhoto, onToggleRecording: _toggleRecording,
                      onToggleChecklist: _toggleChecklist, onNotesChanged: _onNotesChanged)
                  : _ScrollContent(
                      isRecording: _isRecording, waveCtrl: _waveCtrl,
                      recordPulse: _recordPulse, photos: _photos, clips: _clips, checklist: _checklist, notesCtrl: _notesCtrl,
                      onCapturePhoto: _capturePhoto, onToggleRecording: _toggleRecording,
                      onToggleChecklist: _toggleChecklist, onNotesChanged: _onNotesChanged,
                      onEnd: _ending ? () {} : _endVisit),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({required this.projectName, required this.timerLabel, required this.isTabbed, required this.busy, required this.onToggleLayout, required this.onEnd});
  final String projectName, timerLabel;
  final bool isTabbed, busy;
  final VoidCallback onToggleLayout, onEnd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.bgCard,
        child: Row(
          children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Site Inspection', style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                Text(projectName, style: AppText.spaceGrotesk(size: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            )),
            Text(timerLabel, style: AppText.jetBrainsMono(size: 15, weight: FontWeight.w700, color: AppColors.copperMid)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onEnd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  border: Border.all(color: AppColors.red.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(busy ? '…' : 'End', style: AppText.spaceGrotesk(size: 12, color: AppColors.red, weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggleLayout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.bgCardElevated, borderRadius: BorderRadius.circular(20)),
                child: Text(isTabbed ? 'SCROLL' : 'TAB',
                    style: AppText.spaceGrotesk(size: 10, weight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      );
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.activeTab, required this.onTabChanged});
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  static const _tabs = ['Photos', 'Voice', 'Checklist', 'Notes'];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) => Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: i == activeTab ? AppColors.copperMid : Colors.transparent, width: 2)),
                ),
                alignment: Alignment.center,
                child: Text(_tabs[i], style: AppText.spaceGrotesk(
                  size: 11, weight: FontWeight.w600,
                  color: i == activeTab ? AppColors.copperMid : AppColors.textMuted,
                )),
              ),
            ),
          )),
        ),
      );
}

class _TabbedContent extends StatelessWidget {
  const _TabbedContent({
    required this.tab, required this.isRecording, required this.waveCtrl, required this.recordPulse,
    required this.photos, required this.clips, required this.checklist, required this.notesCtrl,
    required this.playingClipId, required this.onPlayClip, required this.onDeleteClip,
    required this.onCapturePhoto, required this.onToggleRecording, required this.onToggleChecklist, required this.onNotesChanged,
  });
  final int tab;
  final bool isRecording;
  final AnimationController waveCtrl, recordPulse;
  final List<Photo> photos;
  final List<VoiceClip> clips;
  final List<ChecklistItem> checklist;
  final TextEditingController notesCtrl;
  final int? playingClipId;
  final ValueChanged<VoiceClip> onPlayClip;
  final ValueChanged<VoiceClip> onDeleteClip;
  final VoidCallback onCapturePhoto, onToggleRecording;
  final ValueChanged<ChecklistItem> onToggleChecklist;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 0: return _PhotosPane(photos: photos, onCapture: onCapturePhoto);
      case 1: return _VoicePane(isRecording: isRecording, waveCtrl: waveCtrl, recordPulse: recordPulse, clips: clips, onToggle: onToggleRecording, playingClipId: playingClipId, onPlayClip: onPlayClip, onDeleteClip: onDeleteClip);
      case 2: return _ChecklistPane(items: checklist, onToggle: onToggleChecklist);
      case 3: return _NotesPane(controller: notesCtrl, onChanged: onNotesChanged);
      default: return const SizedBox.shrink();
    }
  }
}

class _ScrollContent extends StatelessWidget {
  const _ScrollContent({
    required this.isRecording, required this.waveCtrl, required this.recordPulse,
    required this.photos, required this.clips, required this.checklist, required this.notesCtrl,
    required this.onCapturePhoto, required this.onToggleRecording, required this.onToggleChecklist, required this.onNotesChanged,
    required this.onEnd,
  });
  final bool isRecording;
  final AnimationController waveCtrl, recordPulse;
  final List<Photo> photos;
  final List<VoiceClip> clips;
  final List<ChecklistItem> checklist;
  final TextEditingController notesCtrl;
  final VoidCallback onCapturePhoto, onToggleRecording, onEnd;
  final ValueChanged<ChecklistItem> onToggleChecklist;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PHOTOS', style: AppText.label),
                const SizedBox(height: 8),
                _PhotoStrip(photos: photos, onCapture: onCapturePhoto),
                const SizedBox(height: 20),
                Text('VOICE', style: AppText.label),
                const SizedBox(height: 8),
                _CompactVoice(isRecording: isRecording, recordPulse: recordPulse, onToggle: onToggleRecording, clipCount: clips.length),
                const SizedBox(height: 20),
                Text('CHECKLIST', style: AppText.label),
                const SizedBox(height: 8),
                _ChecklistItemsList(items: checklist, onToggle: onToggleChecklist),
                const SizedBox(height: 20),
                Text('FIELD NOTES', style: AppText.label),
                const SizedBox(height: 8),
                _NotesPane(controller: notesCtrl, onChanged: onNotesChanged),
              ],
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bgApp.withOpacity(0), AppColors.bgApp]),
              ),
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
              child: CopperButton(label: 'End Visit & Generate Report', onTap: onEnd),
            ),
          ),
        ],
      );
}

// ── Photos ───────────────────────────────────────────────────────────────────

class _PhotosPane extends StatelessWidget {
  const _PhotosPane({required this.photos, required this.onCapture});
  final List<Photo> photos;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onCapture,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.copperMid.withOpacity(0.07),
                  border: Border.all(color: AppColors.copperMid.withOpacity(0.3), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.copperMid),
                    const SizedBox(width: 8),
                    Text('Take Photo', style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w600, color: AppColors.copperMid)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (photos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No photos yet.', style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
              )
            else
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2,
                children: photos.map((p) => _PhotoThumb(photo: p)).toList(),
              ),
          ],
        ),
      );
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo});
  final Photo photo;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: AppColors.bgPlaceholder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(photo.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              if (photo.lat != null)
                Positioned(top: 6, right: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.copperMid, borderRadius: BorderRadius.circular(4)),
                  child: Text('GPS', style: AppText.spaceGrotesk(size: 8, weight: FontWeight.w600, color: Colors.white)),
                )),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent]),
                  ),
                  child: Text(
                    photo.lat != null
                        ? '${photo.lat!.toStringAsFixed(4)}°N ${photo.lng!.toStringAsFixed(4)}°E\n${_time(photo.capturedAt)}'
                        : _time(photo.capturedAt),
                    style: AppText.jetBrainsMono(size: 8, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  String _time(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.onCapture});
  final List<Photo> photos;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...photos.map((p) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 76, height: 76,
                    margin: const EdgeInsets.only(right: 8),
                    color: AppColors.bgPlaceholder,
                    child: Image.file(File(p.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                )),
            GestureDetector(
              onTap: onCapture,
              child: Container(
                width: 76, height: 76,
                decoration: BoxDecoration(border: Border.all(color: AppColors.copperMid.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add, color: AppColors.copperMid, size: 24),
              ),
            ),
          ],
        ),
      );
}

// ── Voice ────────────────────────────────────────────────────────────────────

class _VoicePane extends StatelessWidget {
  const _VoicePane({
    required this.isRecording, required this.waveCtrl, required this.recordPulse, required this.clips,
    required this.onToggle, required this.playingClipId, required this.onPlayClip, required this.onDeleteClip,
  });
  final bool isRecording;
  final AnimationController waveCtrl, recordPulse;
  final List<VoiceClip> clips;
  final VoidCallback onToggle;
  final int? playingClipId;
  final ValueChanged<VoiceClip> onPlayClip;
  final ValueChanged<VoiceClip> onDeleteClip;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _WaveformRow(ctrl: waveCtrl, active: isRecording),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedBuilder(
                animation: recordPulse,
                builder: (_, __) => Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRecording ? [AppColors.red.withOpacity(0.8), AppColors.red] : [AppColors.copperDark, AppColors.copperMid],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: isRecording ? [
                      BoxShadow(color: AppColors.red.withOpacity(0.15 + 0.1 * recordPulse.value), blurRadius: 16, spreadRadius: 8),
                    ] : [
                      BoxShadow(color: AppColors.copperMid.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(isRecording ? 'Recording… tap to stop' : 'Tap to record',
                style: AppText.spaceGrotesk(size: 12, color: isRecording ? AppColors.red : AppColors.textSecondary)),
            if (clips.isNotEmpty)
              ...clips.map((c) => _ClipRow(
                  clip: c,
                  playing: playingClipId == c.id,
                  onPlay: () => onPlayClip(c),
                  onDelete: () => onDeleteClip(c))),
          ],
        ),
      );
}

class _WaveformRow extends StatelessWidget {
  const _WaveformRow({required this.ctrl, required this.active});
  final AnimationController ctrl;
  final bool active;

  static const _maxH = [18.0, 28.0, 14.0, 36.0, 10.0, 24.0, 16.0, 30.0, 12.0, 26.0, 20.0, 8.0];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_maxH.length, (i) {
            final t = active ? ((ctrl.value + i * 0.07) % 1.0) : 0.3;
            final h = active ? (5.0 + (_maxH[i] - 5) * (0.5 - (t - 0.5).abs()) * 2) : 5.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4, height: h.clamp(5, 36),
              decoration: BoxDecoration(color: AppColors.copperLight.withOpacity(active ? 1.0 : 0.25), borderRadius: BorderRadius.circular(2)),
            );
          }),
        ),
      );
}

class _CompactVoice extends StatelessWidget {
  const _CompactVoice({required this.isRecording, required this.recordPulse, required this.onToggle, required this.clipCount});
  final bool isRecording;
  final AnimationController recordPulse;
  final VoidCallback onToggle;
  final int clipCount;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedBuilder(
              animation: recordPulse,
              builder: (_, __) => Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isRecording ? [AppColors.red.withOpacity(0.8), AppColors.red] : [AppColors.copperDark, AppColors.copperMid]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isRecording ? 'Recording… tap to stop' : 'Tap to record', style: AppText.spaceGrotesk(size: 13, color: AppColors.textSecondary)),
              if (clipCount > 0) Text('$clipCount clip${clipCount > 1 ? 's' : ''} saved', style: AppText.spaceGrotesk(size: 11, color: AppColors.copperMid)),
            ],
          ),
        ],
      );
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.clip, required this.playing, required this.onPlay, required this.onDelete});
  final VoiceClip clip;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  String _statusText(TranscriptState state) => switch (state) {
        TranscriptState.running => 'Transcribing…',
        TranscriptState.queued => 'Waiting to transcribe…',
        TranscriptState.paused => 'Transcription paused',
        TranscriptState.none =>
          'No transcript — download the Whisper model or turn on the cloud fallback (Models screen)',
      };

  @override
  Widget build(BuildContext context) {
    final state = appRepository.transcriptStateOf(clip.id);
    final done = clip.transcript.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bgCardElevated, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: playing ? AppColors.copperMid : AppColors.bgCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(playing ? Icons.stop : Icons.play_arrow,
                    size: 18, color: playing ? Colors.white : AppColors.copperMid),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${clip.recordedAt.hour.toString().padLeft(2, '0')}:${clip.recordedAt.minute.toString().padLeft(2, '0')}',
                  style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
              Text('0:${clip.durationSeconds.toString().padLeft(2, '0')}', style: AppText.jetBrainsMono(size: 10)),
            ])),
            if (!done && state != TranscriptState.none)
              GestureDetector(
                onTap: () => state == TranscriptState.paused
                    ? appRepository.resumeTranscription(clip.id)
                    : appRepository.pauseTranscription(clip.id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    state == TranscriptState.paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                    size: 22, color: AppColors.copperMid,
                  ),
                ),
              ),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
              ),
            ),
          ]),
          const Divider(height: 16, color: AppColors.borderSubtle),
          Row(
            children: [
              if (state == TranscriptState.running && !done) ...[
                const SizedBox(
                    width: 11, height: 11,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.copperMid)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(done ? clip.transcript : _statusText(state),
                    style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary, height: 1.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Checklist ────────────────────────────────────────────────────────────────

class _ChecklistPane extends StatelessWidget {
  const _ChecklistPane({required this.items, required this.onToggle});
  final List<ChecklistItem> items;
  final ValueChanged<ChecklistItem> onToggle;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: _ChecklistItemsList(items: items, onToggle: onToggle),
      );
}

class _ChecklistItemsList extends StatelessWidget {
  const _ChecklistItemsList({required this.items, required this.onToggle});
  final List<ChecklistItem> items;
  final ValueChanged<ChecklistItem> onToggle;

  @override
  Widget build(BuildContext context) => Column(
        children: items.map((item) => _CheckItem(item: item, onToggle: () => onToggle(item))).toList(),
      );
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.item, required this.onToggle});
  final ChecklistItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: item.completed ? AppColors.copperMid : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: item.completed ? null : Border.all(color: const Color(0xFF3A3028), width: 1.5),
                ),
                child: item.completed ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.label, style: AppText.spaceGrotesk(size: 14, color: item.completed ? AppColors.textMuted : AppColors.textPrimary)),
              ),
            ],
          ),
        ),
      );
}

// ── Notes ────────────────────────────────────────────────────────────────────

class _NotesPane extends StatelessWidget {
  const _NotesPane({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                onChanged: onChanged,
                maxLines: null,
                minLines: 4,
                style: AppText.spaceGrotesk(size: 14),
                decoration: InputDecoration(
                  hintText: 'Tap to add field notes…',
                  hintStyle: AppText.spaceGrotesk(size: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text('Autosaves as you type', style: AppText.spaceGrotesk(size: 10, color: AppColors.textMuted), textAlign: TextAlign.right),
            ],
          ),
        ),
      );
}
