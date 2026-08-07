import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/database.dart';

/// Tamper-evident sealing for visit reports.
///
/// A random 256-bit secret is generated once per install and kept in the
/// platform keystore (Android Keystore / iOS Keychain via
/// flutter_secure_storage). Reports carry sha256(content) plus an
/// HMAC-SHA256 of that digest under the device secret, plus a short key id
/// identifying which device sealed it.
/// ponytail: HMAC with a device secret, not asymmetric signatures — upgrade
/// to Keystore-held EC keys + real signatures if third-party verification
/// without the device ever becomes a requirement.
class SealService {
  static const _storage = FlutterSecureStorage();
  static const _secretKey = 'report_seal_secret';

  Future<List<int>> _secret() async {
    var stored = await _storage.read(key: _secretKey);
    if (stored == null) {
      final rng = Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      stored = base64Encode(bytes);
      await _storage.write(key: _secretKey, value: stored);
    }
    return base64Decode(stored);
  }

  /// Returns (hmacHex, keyId) for a hex content digest.
  Future<(String, String)> seal(String digestHex) async {
    final secret = await _secret();
    final hmac = Hmac(sha256, secret).convert(utf8.encode(digestHex)).toString();
    final keyId = sha256.convert(secret).toString().substring(0, 8);
    return (hmac, keyId);
  }

  /// Canonical seal for a visit report: (contentHash, hmac, keyId).
  ///
  /// The payload below IS the verification contract — anything that ever
  /// re-checks a seal must hash byte-identical JSON, so it lives here and
  /// nowhere else.
  Future<(String, String, String)> sealVisit({
    required Visit visit,
    required Project project,
    required List<ChecklistItem> checklist,
    required List<VoiceClip> clips,
    required int photoCount,
  }) async {
    final payload = jsonEncode({
      'visit': visit.id,
      'project': project.name,
      'officer': visit.officerName,
      'started_at': visit.startedAt.toUtc().toIso8601String(),
      'ended_at': visit.endedAt?.toUtc().toIso8601String(),
      'gps': [visit.startLat, visit.startLng, visit.gpsAccuracyMeters],
      'notes': visit.notes,
      'checklist': checklist.map((c) => [c.label, c.completed]).toList(),
      'transcripts': clips.map((c) => c.transcript).toList(),
      'photos': photoCount,
    });
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final (hmac, keyId) = await seal(hash);
    return (hash, hmac, keyId);
  }
}
