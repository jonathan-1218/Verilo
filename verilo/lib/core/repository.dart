import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';

/// Default checklist seeded onto every new visit. Editable templates per
/// project category would be the natural next step; out of scope here.
const kDefaultChecklist = [
  'Perimeter security check',
  'Water quality test completed',
  'Pump station inspection',
  'Pipeline integrity scan',
  'Safety signage verified',
];

/// Supabase is the source of truth; every read/write also mirrors into the
/// local drift cache so project/visit lists still render offline. Writes go
/// to Supabase first — if that fails (offline), they land in drift only and
/// get picked up next time a `allX()` read succeeds online.
/// ponytail: no conflict resolution / outbox queue — last write wins, and an
/// offline write is only retried by whatever screen re-reads that list next.
class AppRepository {
  AppRepository(this._db, this._client);
  final AppDatabase _db;
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<List<Project>> allProjects() async {
    try {
      final rows = await _client.from('projects').select().order('created_at');
      final projects = rows.map(_projectFromRow).toList();
      for (final p in projects) {
        await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(p));
      }
      return projects;
    } catch (_) {
      return _db.allProjects();
    }
  }

  Future<Project?> projectById(int id) async {
    for (final p in await allProjects()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Project> createProject({
    required String name,
    required String category,
    required String location,
    required String district,
    required String state,
    double? lat,
    double? lng,
    double geofenceMeters = 500,
    List<String> sdgTags = const [],
    String description = '',
    int budgetCents = 0,
    DateTime? startDate,
    DateTime? endDate,
    String reviewInterval = 'Quarterly',
  }) async {
    final row = await _client.from('projects').insert({
      'owner_id': _uid,
      'name': name,
      'category': category,
      'location': location,
      'district': district,
      'state': state,
      'lat': lat,
      'lng': lng,
      'geofence_meters': geofenceMeters,
      'sdg_tags': sdgTags.join(','),
      'description': description,
      'budget_cents': budgetCents,
      'start_date': startDate?.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'review_interval': reviewInterval,
    }).select().single();
    final project = _projectFromRow(row);
    await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(project));
    return project;
  }

  Project _projectFromRow(Map<String, dynamic> r) => Project(
        id: r['id'] as int,
        name: r['name'] as String,
        category: r['category'] as String,
        location: r['location'] as String,
        district: r['district'] as String,
        state: r['state'] as String,
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        geofenceMeters: (r['geofence_meters'] as num).toDouble(),
        sdgTags: r['sdg_tags'] as String,
        description: r['description'] as String,
        budgetCents: r['budget_cents'] as int,
        startDate: r['start_date'] == null ? null : DateTime.parse(r['start_date'] as String).toLocal(),
        endDate: r['end_date'] == null ? null : DateTime.parse(r['end_date'] as String).toLocal(),
        reviewInterval: r['review_interval'] as String,
        status: r['status'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );

  ProjectsCompanion _projectToCompanion(Project p) => ProjectsCompanion.insert(
        id: Value(p.id),
        name: p.name,
        category: p.category,
        location: p.location,
        district: p.district,
        state: p.state,
        lat: Value(p.lat),
        lng: Value(p.lng),
        geofenceMeters: Value(p.geofenceMeters),
        sdgTags: Value(p.sdgTags),
        description: Value(p.description),
        budgetCents: Value(p.budgetCents),
        startDate: Value(p.startDate),
        endDate: Value(p.endDate),
        reviewInterval: Value(p.reviewInterval),
        status: Value(p.status),
        createdAt: Value(p.createdAt),
      );

  // ── Visits ────────────────────────────────────────────────────────────────

  Future<List<Visit>> allMyVisits() async {
    try {
      final rows = await _client.from('visits').select().order('started_at');
      final visits = rows.map(_visitFromRow).toList();
      for (final v in visits) {
        await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(v));
      }
      return visits;
    } catch (_) {
      return _db.allVisits();
    }
  }

  Future<List<Visit>> visitsForProject(int projectId) async {
    try {
      final rows = await _client.from('visits').select().eq('project_id', projectId).order('started_at');
      final visits = rows.map(_visitFromRow).toList();
      for (final v in visits) {
        await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(v));
      }
      return visits;
    } catch (_) {
      return _db.visitsForProject(projectId);
    }
  }

  Future<Visit?> visitById(int id) async {
    try {
      final row = await _client.from('visits').select().eq('id', id).single();
      final visit = _visitFromRow(row);
      await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(visit));
      return visit;
    } catch (_) {
      return (_db.select(_db.visits)..where((v) => v.id.equals(id))).getSingleOrNull();
    }
  }

  Future<Visit> startVisit({
    required int projectId,
    required String officerName,
    double? startLat,
    double? startLng,
    double? gpsAccuracyMeters,
  }) async {
    final row = await _client.from('visits').insert({
      'owner_id': _uid,
      'project_id': projectId,
      'officer_name': officerName,
      'start_lat': startLat,
      'start_lng': startLng,
      'gps_accuracy_meters': gpsAccuracyMeters,
    }).select().single();
    final visit = _visitFromRow(row);
    await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(visit));

    for (final label in kDefaultChecklist) {
      await addChecklistItem(visit.id, label);
    }
    return visit;
  }

  Future<void> updateVisitNotes(Visit visit, String notes) async {
    try {
      await _client.from('visits').update({'notes': notes}).eq('id', visit.id);
    } catch (_) {
      // offline: local copy below still gets the latest notes
    }
    await _db.updateVisit(visit.copyWith(notes: notes));
  }

  Future<Visit> endVisit(Visit visit, {String? notes, String? reportHash}) async {
    final row = await _client.from('visits').update({
      // keep the original end time if the visit was already closed (e.g. when
      // re-opening the report just stores the hash) so duration can't drift
      'ended_at': (visit.endedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'status': 'complete',
      if (notes != null) 'notes': notes,
      if (reportHash != null) 'report_hash': reportHash,
    }).eq('id', visit.id).select().single();
    final updated = _visitFromRow(row);
    await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(updated));
    return updated;
  }

  Visit _visitFromRow(Map<String, dynamic> r) => Visit(
        id: r['id'] as int,
        projectId: r['project_id'] as int,
        officerName: r['officer_name'] as String,
        startedAt: DateTime.parse(r['started_at'] as String).toLocal(),
        endedAt: r['ended_at'] == null ? null : DateTime.parse(r['ended_at'] as String).toLocal(),
        startLat: (r['start_lat'] as num?)?.toDouble(),
        startLng: (r['start_lng'] as num?)?.toDouble(),
        gpsAccuracyMeters: (r['gps_accuracy_meters'] as num?)?.toDouble(),
        notes: r['notes'] as String,
        status: r['status'] as String,
        reportHash: r['report_hash'] as String?,
      );

  VisitsCompanion _visitToCompanion(Visit v) => VisitsCompanion.insert(
        id: Value(v.id),
        projectId: v.projectId,
        officerName: v.officerName,
        startedAt: Value(v.startedAt),
        endedAt: Value(v.endedAt),
        startLat: Value(v.startLat),
        startLng: Value(v.startLng),
        gpsAccuracyMeters: Value(v.gpsAccuracyMeters),
        notes: Value(v.notes),
        status: Value(v.status),
        reportHash: Value(v.reportHash),
      );

  // ── Checklist ─────────────────────────────────────────────────────────────

  Future<List<ChecklistItem>> checklistForVisit(int visitId) async {
    try {
      final rows = await _client.from('checklist_items').select().eq('visit_id', visitId).order('id');
      final items = rows.map(_checklistFromRow).toList();
      for (final i in items) {
        await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(i));
      }
      return items;
    } catch (_) {
      return _db.checklistForVisit(visitId);
    }
  }

  Future<void> addChecklistItem(int visitId, String label) async {
    final row = await _client.from('checklist_items').insert({
      'owner_id': _uid,
      'visit_id': visitId,
      'label': label,
    }).select().single();
    await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(_checklistFromRow(row)));
  }

  Future<void> toggleChecklistItem(ChecklistItem item) async {
    final row = await _client.from('checklist_items')
        .update({'completed': !item.completed}).eq('id', item.id).select().single();
    await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(_checklistFromRow(row)));
  }

  ChecklistItem _checklistFromRow(Map<String, dynamic> r) => ChecklistItem(
        id: r['id'] as int,
        visitId: r['visit_id'] as int,
        label: r['label'] as String,
        completed: r['completed'] as bool,
      );

  ChecklistItemsCompanion _checklistToCompanion(ChecklistItem i) => ChecklistItemsCompanion.insert(
        id: Value(i.id),
        visitId: i.visitId,
        label: i.label,
        completed: Value(i.completed),
      );

  // ── Photos / voice clips ────────────────────────────────────────────────
  // Captured locally first (camera/mic must work offline); metadata is
  // pushed to Supabase best-effort so it shows up cross-device once online.
  // ponytail: uploading the actual photo/audio bytes to Storage is deferred
  // (see supabase/schema.sql) — only the row metadata syncs today.

  Future<List<Photo>> photosForVisit(int visitId) => _db.photosForVisit(visitId);

  Future<void> syncPhoto(Photo photo) async {
    try {
      // no client id: the column is `generated always as identity`, so the
      // server assigns it (a client-sent id would be rejected outright)
      await _client.from('photos').insert({
        'owner_id': _uid,
        'visit_id': photo.visitId,
        'lat': photo.lat,
        'lng': photo.lng,
        'accuracy_meters': photo.accuracyMeters,
        'captured_at': photo.capturedAt.toUtc().toIso8601String(),
      });
    } catch (_) {
      // offline: stays local-only until the next successful sync
    }
  }

  Future<List<VoiceClip>> clipsForVisit(int visitId) => _db.clipsForVisit(visitId);

  Future<VoiceClip> saveVoiceClip({required int visitId, required String filePath, required int durationSeconds}) async {
    final id = await _db.insertClip(VoiceClipsCompanion.insert(
      visitId: visitId,
      filePath: filePath,
      durationSeconds: Value(durationSeconds),
    ));
    final clip = await (_db.select(_db.voiceClips)..where((c) => c.id.equals(id))).getSingle();
    await syncVoiceClip(clip);
    return clip;
  }

  Future<void> syncVoiceClip(VoiceClip clip) async {
    try {
      await _client.from('voice_clips').insert({
        'owner_id': _uid,
        'visit_id': clip.visitId,
        'duration_seconds': clip.durationSeconds,
        'transcript': clip.transcript,
        'recorded_at': clip.recordedAt.toUtc().toIso8601String(),
      });
    } catch (_) {
      // offline: stays local-only until the next successful sync
    }
  }
}
