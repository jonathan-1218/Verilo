import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/database.dart';

class PdfService {
  static const _copper = PdfColor.fromInt(0xFFB87040);
  static const _text = PdfColor.fromInt(0xFF111827);
  static const _muted = PdfColor.fromInt(0xFF6B7280);

  /// Generates the sealed PDF and writes it to disk, returning its file path.
  /// The seal values (content hash + device HMAC + key id) are computed by
  /// the caller over the canonical report payload — they can't be a hash of
  /// the PDF bytes because they are printed inside the PDF itself.
  Future<String> generateReport({
    required Visit visit,
    required Project project,
    required List<Photo> photos,
    required List<VoiceClip> clips,
    required String aiSummary,
    required String sealHash,
    required String sealHmac,
    required String sealKeyId,
    String? address, // reverse-geocoded, display-only (not part of the seal)
  }) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      build: (ctx) => [
        _header(project, visit),
        pw.SizedBox(height: 20),
        _section('Project Details', [
          ('Project', project.name),
          ('Category', project.category),
          ('Location', '${project.district}, ${project.state}'),
          ('GPS', visit.startLat != null ? '${visit.startLat!.toStringAsFixed(4)}°N ${visit.startLng!.toStringAsFixed(4)}°E' : '—'),
          if (address != null) ('Address', address),
        ]),
        pw.SizedBox(height: 12),
        _section('Visit Information', [
          ('Date', _fmtDate(visit.startedAt)),
          ('Officer', visit.officerName),
          ('Duration', _duration(visit.startedAt, visit.endedAt)),
          ('GPS Accuracy', visit.gpsAccuracyMeters != null ? '±${visit.gpsAccuracyMeters!.round()} m' : '—'),
        ]),
        if (clips.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _section('Field Notes', [
            ('AI Summary', aiSummary.isNotEmpty ? aiSummary : '—'),
            ('Clips', '${clips.length} voice recording${clips.length > 1 ? 's' : ''}'),
          ]),
          ...clips.map((c) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(c.filePath.split('/').last, style: pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(c.transcript, style: pw.TextStyle(fontSize: 10, color: _text)),
            ]),
          )),
        ],
        if (visit.notes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _section('Field Notes (Manual)', [('Notes', visit.notes)]),
        ],
        pw.SizedBox(height: 20),
        _integrity(sealHash, sealHmac, sealKeyId),
      ],
    ));

    final bytes = await doc.save();
    // stable name: re-opening a report overwrites the same file instead of
    // leaking a new timestamped PDF per view
    final path = await reportPath(visit.id);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Where the report PDF for [visitId] lives (whether or not it exists yet).
  static Future<String> reportPath(int visitId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/report_$visitId.pdf';
  }

  pw.Widget _header(Project project, Visit visit) => pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: const pw.BoxDecoration(color: _copper),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Site Visit Report', style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'veri', style: pw.TextStyle(color: const PdfColor.fromInt(0xFFD4956A), fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: 'lo', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ])),
          ],
        ),
      );

  pw.Widget _section(String title, List<(String, String)> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: _muted, letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: rows.map((r) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 100, child: pw.Text(r.$1, style: pw.TextStyle(fontSize: 9, color: _muted))),
                  pw.Expanded(child: pw.Text(r.$2, style: pw.TextStyle(fontSize: 9, color: _text, fontWeight: pw.FontWeight.bold))),
                ],
              ),
            )).toList()),
          ),
        ],
      );

  pw.Widget _integrity(String hash, String hmac, String keyId) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('INTEGRITY SEAL', style: pw.TextStyle(fontSize: 8, color: _muted, letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Text('SHA-256  $hash', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: _text)),
          pw.Text('HMAC     $hmac', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: _text)),
          pw.Text('KEY ID   $keyId', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: _copper)),
          pw.SizedBox(height: 4),
          pw.Text('Content digest sealed with a device-held secret at capture time.',
              style: pw.TextStyle(fontSize: 7, color: _muted)),
        ]),
      );

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1]} ${dt.year}';

  String _duration(DateTime start, DateTime? end) {
    final d = (end ?? DateTime.now()).difference(start);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
