import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';
import '../services/pdf_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.visitId});
  final int visitId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Visit? _visit;
  Project? _project;
  List<Photo> _photos = [];
  List<VoiceClip> _clips = [];
  List<ChecklistItem> _checklist = [];
  String? _pdfPath;
  String? _pdfHash;
  String? _pdfSignature;
  String? _address;
  bool _loading = true;

  /// Reverse-geocoded address for the visit's start point. Display-only —
  /// never part of the sealed payload. Fail-quiet: offline or no geocoder
  /// just means the row shows coordinates alone.
  Future<String?> _resolveAddress(Visit visit) async {
    if (visit.startLat == null || visit.startLng == null) return null;
    try {
      final places = await placemarkFromCoordinates(visit.startLat!, visit.startLng!);
      if (places.isEmpty) return null;
      final p = places.first;
      final parts = [p.street, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var visit = await appRepository.visitById(widget.visitId);
    final project = visit == null ? null : await appRepository.projectById(visit.projectId);
    if (visit == null || project == null) {
      if (mounted) setState(() => _loading = false); // build() shows the error state
      return;
    }
    final photos = await appRepository.photosForVisit(widget.visitId);
    final clips = await appRepository.clipsForVisit(widget.visitId);
    final checklist = await appRepository.checklistForVisit(widget.visitId);
    final address = await _resolveAddress(visit);

    // Seal once: the first open computes hash+HMAC (SealService owns the
    // canonical payload) and stores them; every later open reuses the stored
    // record so screen, PDF, and DB always show the same seal. A visit sealed
    // under the old PDF-bytes scheme has no reportSignature — it falls into
    // the else-branch once and is re-sealed under the content-hash scheme.
    String hash, hmac, keyId;
    final sealed = visit.reportHash != null && visit.reportSignature != null;
    if (sealed) {
      hash = visit.reportHash!;
      final sep = visit.reportSignature!.indexOf(':');
      keyId = visit.reportSignature!.substring(0, sep);
      hmac = visit.reportSignature!.substring(sep + 1);
    } else {
      (hash, hmac, keyId) = await sealService.sealVisit(
        visit: visit, project: project, checklist: checklist, clips: clips, photoCount: photos.length);
      visit = await appRepository.endVisit(visit, reportHash: hash, reportSignature: '$keyId:$hmac');
    }

    // an already-sealed report with its PDF on disk is immutable — skip the
    // summarize network call and regeneration entirely
    var path = await PdfService.reportPath(visit.id);
    if (!sealed || !File(path).existsSync()) {
      final aiSummary = await summaryService.summarize(
        clips.map((c) => c.transcript).toList(),
        visit.notes,
      );
      path = await PdfService().generateReport(
        visit: visit, project: project, photos: photos, clips: clips,
        aiSummary: aiSummary, address: address,
        sealHash: hash, sealHmac: hmac, sealKeyId: keyId,
      );
    }
    if (!mounted) return;
    setState(() {
      _visit = visit; _project = project; _photos = photos; _clips = clips; _checklist = checklist;
      _address = address;
      _pdfPath = path;
      _pdfHash = hash;
      _pdfSignature = '$keyId:$hmac';
      _loading = false;
    });
  }

  Future<void> _sharePdf() async {
    final path = _pdfPath;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: 'verilo-report-${widget.visitId}.pdf');
  }

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _duration(DateTime start, DateTime? end) {
    final d = (end ?? DateTime.now()).difference(start);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bgApp, body: Center(child: CircularProgressIndicator(color: AppColors.copperMid)));
    }
    if (_visit == null || _project == null) {
      return Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Report unavailable', style: AppText.screenTitle),
                const SizedBox(height: 8),
                Text('This visit could not be loaded. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                CopperButton(label: 'Go back', onTap: () => context.pop(), fullWidth: false),
              ],
            ),
          ),
        ),
      );
    }
    final visit = _visit!, project = _project!;
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Report Ready', style: AppText.screenTitle)),
                  GestureDetector(
                    onTap: _sharePdf,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.borderSubtle), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Icon(Icons.share_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Share', style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: const BoxDecoration(color: AppColors.copperMid, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                            child: Row(children: [
                              Text('Site Visit Report', style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w700, color: Colors.white)),
                              const Spacer(),
                              RichText(text: TextSpan(children: [
                                TextSpan(text: 'veri', style: AppText.spaceGrotesk(size: 12, weight: FontWeight.w700, color: AppColors.copperGlow)),
                                TextSpan(text: 'lo', style: AppText.spaceGrotesk(size: 12, weight: FontWeight.w700, color: Colors.white)),
                              ])),
                            ]),
                          ),
                          _PDFSection(title: 'Project Details', rows: [
                            ('Project', project.name),
                            ('Category', project.category),
                            ('Location', '${project.district}, ${project.state}'),
                            ('SDG Tags', project.sdgTags.replaceAll(',', ', ')),
                          ]),
                          const Divider(height: 1, color: Color(0xFFF0EDE9)),
                          _PDFSection(title: 'Visit Information', rows: [
                            ('Date', _fmtDate(visit.startedAt)),
                            ('Officer', visit.officerName),
                            ('Duration', _duration(visit.startedAt, visit.endedAt)),
                            ('GPS Start', visit.startLat != null ? '${visit.startLat!.toStringAsFixed(4)}°N ${visit.startLng!.toStringAsFixed(4)}°E' : '—'),
                            ('Address', _address ?? '—'),
                            ('Accuracy', visit.gpsAccuracyMeters != null ? '±${visit.gpsAccuracyMeters!.round()} m' : '—'),
                          ]),
                          const Divider(height: 1, color: Color(0xFFF0EDE9)),
                          _PDFPhotoSection(photos: _photos),
                          const Divider(height: 1, color: Color(0xFFF0EDE9)),
                          _PDFSection(title: 'Field Notes', rows: [
                            ('Voice transcripts', _clips.isEmpty ? '—' : '${_clips.length} recording${_clips.length > 1 ? 's' : ''}'),
                            ('Manual notes', visit.notes.isEmpty ? '—' : visit.notes),
                            ('Checklist', '${_checklist.where((c) => c.completed).length} / ${_checklist.length} items completed'),
                          ]),
                          const Divider(height: 1, color: Color(0xFFF0EDE9)),
                          _IntegritySection(hash: _pdfHash ?? '', signature: _pdfSignature ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: CopperButton(label: 'Download / Share PDF', onTap: _sharePdf)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.go('/dashboard'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: AppColors.borderSubtle), borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.center,
                              child: Text('Home', style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary)),
                            ),
                          ),
                        ),
                      ],
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

class _PDFSection extends StatelessWidget {
  const _PDFSection({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF9A8F88), letterSpacing: 1)),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 100, child: Text(r.$1, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)))),
                  Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                ],
              ),
            )),
          ],
        ),
      );
}

class _PDFPhotoSection extends StatelessWidget {
  const _PDFPhotoSection({required this.photos});
  final List<Photo> photos;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GEO-VERIFIED PHOTOS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF9A8F88), letterSpacing: 1)),
            const SizedBox(height: 10),
            if (photos.isEmpty)
              const Text('No photos captured', style: TextStyle(fontSize: 10, color: Color(0xFF9A8F88)))
            else
              Row(children: photos.take(3).toList().asMap().entries.map((e) {
                final i = e.key, p = e.value;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    height: 60,
                    decoration: BoxDecoration(color: const Color(0xFF2E2A26), borderRadius: BorderRadius.circular(6)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.file(File(p.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                );
              }).toList()),
          ],
        ),
      );
}

class _IntegritySection extends StatelessWidget {
  const _IntegritySection({required this.hash, required this.signature});
  final String hash;
  final String signature;

  @override
  Widget build(BuildContext context) {
    final parts = signature.split(':');
    final keyId = parts.length == 2 ? parts[0] : '—';
    final hmac = parts.length == 2 ? parts[1] : signature;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFFF5F5F4), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INTEGRITY SEAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF9A8F88), letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Text('SHA-256  $hash\nHMAC     $hmac\nKEY ID   $keyId',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF374151))),
          ),
        ],
      ),
    );
  }
}
