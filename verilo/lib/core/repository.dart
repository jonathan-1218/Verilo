import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart' show Uint8List, ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';

/// Where a clip sits in the transcription queue. `none` also covers clips
/// that are already transcribed or have no transcription path.
enum TranscriptState { none, queued, running, paused }

/// Checklist seeded onto every new visit, picked by project category.
/// ponytail: hardcoded templates; move to a `checklist_templates` table when
/// officers need to edit them per project.
const kDefaultChecklist = [
  'Perimeter security check',
  'Site condition documented',
  'Beneficiary interaction recorded',
  'Safety signage verified',
  'Progress vs plan noted',
];

const kChecklistsByCategory = {
  'WASH': [
    'Perimeter security check',
    'Water quality test completed',
    'Pump station inspection',
    'Pipeline integrity scan',
    'Safety signage verified',
  ],
  'Education': [
    'Classroom condition inspected',
    'Teaching equipment verified',
    'Student attendance recorded',
    'Teacher training progress noted',
    'Safety signage verified',
  ],
  'Skill Dev': [
    'Training facility inspected',
    'Equipment and tools verified',
    'Trainee attendance recorded',
    'Placement progress noted',
    'Safety signage verified',
  ],
  'Health': [
    'Facility hygiene inspected',
    'Medical supplies verified',
    'Patient footfall recorded',
    'Staff availability confirmed',
    'Safety signage verified',
  ],
  'Environment': [
    'Plantation survival count',
    'Soil and irrigation checked',
    'Maintenance activity verified',
    'Encroachment / damage noted',
    'Safety signage verified',
  ],
};

/// Supabase is the source of truth; every read/write also mirrors into the
/// local drift cache so project/visit lists still render offline. Writes
/// that fail (offline) land in the `outbox` table and are replayed by
/// [flushOutbox] once the app is back online, oldest first.
class AppRepository {
  AppRepository(this._db, this._client, {this.transcriber});
  final AppDatabase _db;
  final SupabaseClient _client;

  /// Optional cloud transcription hook (see TranscriptionService). Kept as a
  /// plain function so the repository doesn't depend on the services layer.
  final Future<String?> Function(String filePath)? transcriber;

  String get _uid => _client.auth.currentUser!.id;

  // Local-only placeholder ids for rows created while offline, reconciled to
  // the server-assigned id once the create reaches Supabase. Seeded from the
  // clock so ids stay unique across app restarts too.
  // ponytail: millis-seeded counter, good enough for one device's offline
  // queue; swap for a uuid if cross-restart collisions ever show up.
  int _localSeq = DateTime.now().millisecondsSinceEpoch;
  int _localId() => -(_localSeq++);

  Future<void> _enqueue(String entity, String op, int id) => _db.into(_db.outbox).insert(
        OutboxCompanion.insert(entity: entity, op: op, payload: jsonEncode({'id': id})),
      );

  // Read paths fall back to the local cache on any failure, but a bad DNS
  // lookup doesn't fail fast — Supabase's own auth-refresh retries for well
  // over a minute before the request even errors. Bound every read fetch so
  // a dead network still shows cached data promptly instead of hanging the
  // screen behind that retry cascade.
  Future<T> _bounded<T>(Future<T> Function() fetch) => fetch().timeout(const Duration(seconds: 6));

  /// Rewrites everything that pointed at [oldId] to [newId]: child rows'
  /// foreign keys in drift, and any not-yet-replayed outbox entry for the
  /// same entity/id (so a queued update on a row created offline still
  /// targets the right id once the create is reconciled).
  Future<void> _reconcileId(String entity, int oldId, int newId) async {
    switch (entity) {
      case 'projects':
        await (_db.update(_db.visits)..where((v) => v.projectId.equals(oldId)))
            .write(VisitsCompanion(projectId: Value(newId)));
      case 'visits':
        await (_db.update(_db.photos)..where((p) => p.visitId.equals(oldId)))
            .write(PhotosCompanion(visitId: Value(newId)));
        await (_db.update(_db.voiceClips)..where((c) => c.visitId.equals(oldId)))
            .write(VoiceClipsCompanion(visitId: Value(newId)));
        await (_db.update(_db.checklistItems)..where((i) => i.visitId.equals(oldId)))
            .write(ChecklistItemsCompanion(visitId: Value(newId)));
    }
    final pending = await (_db.select(_db.outbox)..where((o) => o.entity.equals(entity))).get();
    for (final row in pending) {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      if (payload['id'] == oldId) {
        await (_db.update(_db.outbox)..where((o) => o.id.equals(row.id)))
            .write(OutboxCompanion(payload: Value(jsonEncode({'id': newId}))));
      }
    }
  }

  /// Ids (local or server) with a not-yet-replayed outbox entry. Reads must
  /// not overwrite these rows with server state: the local copy is newer.
  Future<Set<int>> _pendingIds(String entity) async {
    final rows = await (_db.select(_db.outbox)..where((o) => o.entity.equals(entity))).get();
    return rows.map((r) => (jsonDecode(r.payload) as Map<String, dynamic>)['id'] as int).toSet();
  }

  bool _flushing = false;

  /// Replays queued writes oldest-first. A network failure stops the pass
  /// (still offline, retry later); a permanent failure — the server answered
  /// and rejected the row, or the local media file is gone — drops that entry
  /// so one poison row can't jam the whole queue forever (the local copy is
  /// kept either way). Kicked fire-and-forget from the online read paths, so
  /// the guard keeps overlapping passes from replaying the same row twice.
  Future<void> flushOutbox() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _flushOutboxOnce();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushOutboxOnce() async {
    final pending = await (_db.select(_db.outbox)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
    for (final row in pending) {
      final id = (jsonDecode(row.payload) as Map<String, dynamic>)['id'] as int;
      try {
        switch ((row.entity, row.op)) {
          case ('projects', 'insert'):
            final local = await (_db.select(_db.projects)..where((p) => p.id.equals(id))).getSingleOrNull();
            if (local != null) await _pushProject(local);
          case ('visits', 'insert'):
            final local = await (_db.select(_db.visits)..where((v) => v.id.equals(id))).getSingleOrNull();
            if (local != null) await _pushVisit(local);
          case ('visits', 'update'):
            final local = await (_db.select(_db.visits)..where((v) => v.id.equals(id))).getSingleOrNull();
            if (local != null) await _pushVisitUpdate(local);
          case ('checklist_items', 'insert'):
            final local = await (_db.select(_db.checklistItems)..where((i) => i.id.equals(id))).getSingleOrNull();
            if (local != null) await _pushChecklistInsert(local);
          case ('checklist_items', 'update'):
            final local = await (_db.select(_db.checklistItems)..where((i) => i.id.equals(id))).getSingleOrNull();
            if (local != null) await _pushChecklistUpdate(local);
          case ('photos', 'insert'):
            final local = await (_db.select(_db.photos)..where((p) => p.id.equals(id))).getSingleOrNull();
            if (local != null) await _uploadPhoto(local);
          case ('voice_clips', 'insert'):
            final local = await (_db.select(_db.voiceClips)..where((c) => c.id.equals(id))).getSingleOrNull();
            if (local != null) await _uploadVoiceClip(local);
        }
      } on PostgrestException {
        // server rejected the row (constraint/RLS/0-row update) — replaying
        // can never succeed; fall through and drop the entry
        // ponytail: treats every postgrest error as permanent; split out
        // retryable codes if a flaky gateway ever surfaces here
      } on StorageException catch (e) {
        if ((int.tryParse(e.statusCode ?? '') ?? 500) >= 500) break; // transient
      } on FileSystemException {
        // local media file was deleted before it could upload — unrecoverable
      } catch (_) {
        break; // offline again — leave the rest of the queue for next time
      }
      await (_db.delete(_db.outbox)..where((o) => o.id.equals(row.id))).go();
    }
  }

  // ── Projects ──────────────────────────────────────────────────────────────

  // Read paths merge server rows into drift and then read back from drift:
  // rows with a queued outbox write are skipped during the merge (local is
  // newer than the server until the replay lands), and rows created offline
  // (negative ids, not on the server yet) stay visible in every list.

  Future<List<Project>> allProjects() async {
    unawaited(flushOutbox());
    unawaited(_syncProjects());
    return _db.allProjects();
  }

  Future<void> _syncProjects() async {
    try {
      final rows = await _bounded(() => _client.from('projects').select().order('created_at'));
      final dirty = await _pendingIds('projects');
      for (final p in rows.map(_projectFromRow)) {
        if (!dirty.contains(p.id)) {
          await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(p));
        }
      }
    } catch (_) {
      // offline: the local cache is all we have
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
    String implementingAgency = '',
    String csrRegistrationNo = '',
    int beneficiaries = 0,
  }) async {
    final project = Project(
      id: _localId(),
      name: name,
      category: category,
      location: location,
      district: district,
      state: state,
      lat: lat,
      lng: lng,
      geofenceMeters: geofenceMeters,
      sdgTags: sdgTags.join(','),
      description: description,
      budgetCents: budgetCents,
      startDate: startDate,
      endDate: endDate,
      reviewInterval: reviewInterval,
      status: 'Active',
      implementingAgency: implementingAgency,
      csrRegistrationNo: csrRegistrationNo,
      beneficiaries: beneficiaries,
      createdAt: DateTime.now(),
    );
    try {
      final row = await _client.from('projects').insert(_projectFields(project)).select().single();
      final synced = _projectFromRow(row);
      await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(synced));
      return synced;
    } catch (_) {
      await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(project));
      await _enqueue('projects', 'insert', project.id);
      return project;
    }
  }

  Map<String, dynamic> _projectFields(Project p) => {
        'owner_id': _uid,
        'name': p.name,
        'category': p.category,
        'location': p.location,
        'district': p.district,
        'state': p.state,
        'lat': p.lat,
        'lng': p.lng,
        'geofence_meters': p.geofenceMeters,
        'sdg_tags': p.sdgTags,
        'description': p.description,
        'budget_cents': p.budgetCents,
        'start_date': p.startDate?.toUtc().toIso8601String(),
        'end_date': p.endDate?.toUtc().toIso8601String(),
        'review_interval': p.reviewInterval,
        'implementing_agency': p.implementingAgency,
        'csr_registration_no': p.csrRegistrationNo,
        'beneficiaries': p.beneficiaries,
      };

  Future<void> _pushProject(Project local) async {
    final row = await _client.from('projects').insert(_projectFields(local)).select().single();
    final synced = _projectFromRow(row);
    await _db.into(_db.projects).insertOnConflictUpdate(_projectToCompanion(synced));
    if (synced.id != local.id) {
      await (_db.delete(_db.projects)..where((p) => p.id.equals(local.id))).go();
      await _reconcileId('projects', local.id, synced.id);
    }
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
        // tolerate rows from before the CSR columns migration
        implementingAgency: (r['implementing_agency'] as String?) ?? '',
        csrRegistrationNo: (r['csr_registration_no'] as String?) ?? '',
        beneficiaries: (r['beneficiaries'] as int?) ?? 0,
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
        implementingAgency: Value(p.implementingAgency),
        csrRegistrationNo: Value(p.csrRegistrationNo),
        beneficiaries: Value(p.beneficiaries),
        createdAt: Value(p.createdAt),
      );

  // ── Visits ────────────────────────────────────────────────────────────────

  Future<List<Visit>> allMyVisits() async {
    unawaited(flushOutbox());
    unawaited(_mergeVisits(() => _client.from('visits').select().order('started_at')));
    return _db.allVisits();
  }

  Future<List<Visit>> visitsForProject(int projectId) async {
    unawaited(flushOutbox());
    unawaited(_mergeVisits(() => _client.from('visits').select().eq('project_id', projectId).order('started_at')));
    return _db.visitsForProject(projectId);
  }

  Future<Visit?> visitById(int id) async {
    unawaited(flushOutbox());
    await _mergeVisits(() async => [await _client.from('visits').select().eq('id', id).single()]);
    return (_db.select(_db.visits)..where((v) => v.id.equals(id))).getSingleOrNull();
  }

  Future<void> _mergeVisits(Future<List<Map<String, dynamic>>> Function() fetch) async {
    try {
      final rows = await _bounded(fetch);
      final dirty = await _pendingIds('visits');
      for (final v in rows.map(_visitFromRow)) {
        if (!dirty.contains(v.id)) {
          await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(v));
        }
      }
    } catch (_) {
      // offline: the local cache is all we have
    }
  }

  Future<Visit> startVisit({
    required int projectId,
    required String officerName,
    double? startLat,
    double? startLng,
    double? gpsAccuracyMeters,
  }) async {
    final visit = Visit(
      id: _localId(),
      projectId: projectId,
      officerName: officerName,
      startedAt: DateTime.now(),
      endedAt: null,
      startLat: startLat,
      startLng: startLng,
      gpsAccuracyMeters: gpsAccuracyMeters,
      notes: '',
      status: 'active',
      reportHash: null,
      reportSignature: null,
    );
    Visit result;
    try {
      final row = await _client.from('visits').insert(_visitFields(visit)).select().single();
      result = _visitFromRow(row);
      await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(result));
    } catch (_) {
      await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(visit));
      await _enqueue('visits', 'insert', visit.id);
      result = visit;
    }

    // local cache only: starting a visit must not wait on the network
    final project = await (_db.select(_db.projects)..where((p) => p.id.equals(projectId))).getSingleOrNull();
    final category = project?.category;
    await Future.wait([
      for (final label in kChecklistsByCategory[category] ?? kDefaultChecklist) addChecklistItem(result.id, label),
    ]);
    return result;
  }

  Map<String, dynamic> _visitFields(Visit v) => {
        'owner_id': _uid,
        'project_id': v.projectId,
        'officer_name': v.officerName,
        'started_at': v.startedAt.toUtc().toIso8601String(),
        'start_lat': v.startLat,
        'start_lng': v.startLng,
        'gps_accuracy_meters': v.gpsAccuracyMeters,
        // full current state, not just creation fields: a visit created
        // offline may already be completed and sealed by the time its
        // insert replays from the outbox
        'notes': v.notes,
        'status': v.status,
        if (v.endedAt != null) 'ended_at': v.endedAt!.toUtc().toIso8601String(),
        if (v.reportHash != null) 'report_hash': v.reportHash,
        if (v.reportSignature != null) 'report_signature': v.reportSignature,
      };

  Future<void> _pushVisit(Visit local) async {
    final row = await _client.from('visits').insert(_visitFields(local)).select().single();
    final synced = _visitFromRow(row);
    await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(synced));
    if (synced.id != local.id) {
      await (_db.delete(_db.visits)..where((v) => v.id.equals(local.id))).go();
      await _reconcileId('visits', local.id, synced.id);
    }
  }

  Future<void> updateVisitNotes(Visit visit, String notes) async {
    final updated = visit.copyWith(notes: notes);
    await _db.updateVisit(updated);
    try {
      await _pushVisitUpdate(updated);
    } catch (_) {
      await _enqueue('visits', 'update', visit.id);
    }
  }

  Future<Visit> endVisit(Visit visit, {String? notes, String? reportHash, String? reportSignature}) async {
    final updated = visit.copyWith(
      // keep the original end time if the visit was already closed (e.g. when
      // re-opening the report just stores the hash) so duration can't drift
      endedAt: Value(visit.endedAt ?? DateTime.now()),
      status: 'complete',
      notes: notes ?? visit.notes,
      reportHash: Value(reportHash ?? visit.reportHash),
      reportSignature: Value(reportSignature ?? visit.reportSignature),
    );
    await _db.into(_db.visits).insertOnConflictUpdate(_visitToCompanion(updated));
    try {
      await _pushVisitUpdate(updated);
    } catch (_) {
      await _enqueue('visits', 'update', visit.id);
    }
    return updated;
  }

  // .select().single() makes a 0-row match throw (row not on the server yet,
  // e.g. a visit still carrying its negative offline id) so the caller's
  // catch enqueues the update instead of silently losing it.
  Future<void> _pushVisitUpdate(Visit v) => _client.from('visits').update({
        'notes': v.notes,
        'status': v.status,
        if (v.endedAt != null) 'ended_at': v.endedAt!.toUtc().toIso8601String(),
        if (v.reportHash != null) 'report_hash': v.reportHash,
        if (v.reportSignature != null) 'report_signature': v.reportSignature,
      }).eq('id', v.id).select().single();

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
        reportSignature: r['report_signature'] as String?,
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
        reportSignature: Value(v.reportSignature),
      );

  // ── Checklist ─────────────────────────────────────────────────────────────

  Future<List<ChecklistItem>> checklistForVisit(int visitId) async {
    unawaited(_syncChecklist(visitId));
    return _db.checklistForVisit(visitId);
  }

  Future<void> _syncChecklist(int visitId) async {
    try {
      final rows = await _bounded(
          () => _client.from('checklist_items').select().eq('visit_id', visitId).order('id'));
      final dirty = await _pendingIds('checklist_items');
      for (final i in rows.map(_checklistFromRow)) {
        if (!dirty.contains(i.id)) {
          await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(i));
        }
      }
    } catch (_) {
      // offline: the local cache is all we have
    }
  }

  Future<void> addChecklistItem(int visitId, String label) async {
    final item = ChecklistItem(id: _localId(), visitId: visitId, label: label, completed: false);
    try {
      final row = await _client.from('checklist_items').insert(_checklistFields(item)).select().single();
      await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(_checklistFromRow(row)));
    } catch (_) {
      await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(item));
      await _enqueue('checklist_items', 'insert', item.id);
    }
  }

  Future<void> toggleChecklistItem(ChecklistItem item) async {
    final updated = item.copyWith(completed: !item.completed);
    try {
      await _pushChecklistUpdate(updated);
    } catch (_) {
      await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(updated));
      await _enqueue('checklist_items', 'update', updated.id);
    }
  }

  Map<String, dynamic> _checklistFields(ChecklistItem i) =>
      // 'completed' rides along so an item checked offline replays checked
      {'owner_id': _uid, 'visit_id': i.visitId, 'label': i.label, 'completed': i.completed};

  Future<void> _pushChecklistInsert(ChecklistItem local) async {
    final row = await _client.from('checklist_items').insert(_checklistFields(local)).select().single();
    final synced = _checklistFromRow(row);
    await _db.into(_db.checklistItems).insertOnConflictUpdate(_checklistToCompanion(synced));
    if (synced.id != local.id) {
      await (_db.delete(_db.checklistItems)..where((i) => i.id.equals(local.id))).go();
      await _reconcileId('checklist_items', local.id, synced.id);
    }
  }

  Future<void> _pushChecklistUpdate(ChecklistItem item) async {
    final row = await _client.from('checklist_items')
        .update({'completed': item.completed}).eq('id', item.id).select().single();
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
  // Captured locally first (camera/mic must work offline); bytes + metadata
  // are pushed to Supabase best-effort so they show up cross-device once
  // online. storage_path is only written after a successful upload, so a
  // null storage_path always means "media exists on this device only".

  Future<List<Photo>> photosForVisit(int visitId) => _db.photosForVisit(visitId);

  // Project-wide media: every photo/clip across all of a project's visits,
  // regardless of visit or project status — raw evidence stays reachable.

  Future<List<Photo>> photosForProject(int projectId) async {
    final visits = await _db.visitsForProject(projectId);
    return [for (final v in visits) ...await _db.photosForVisit(v.id)];
  }

  Future<List<VoiceClip>> clipsForProject(int projectId) async {
    final visits = await _db.visitsForProject(projectId);
    return [for (final v in visits) ...await _db.clipsForVisit(v.id)];
  }

  /// Raw bytes for a media item: the local file when present, otherwise the
  /// uploaded copy. Null when neither is reachable (offline + never synced).
  Future<Uint8List?> mediaBytes({required String filePath, String? storagePath}) async {
    final f = File(filePath);
    if (f.existsSync()) return f.readAsBytes();
    if (storagePath == null) return null;
    try {
      return await _client.storage.from('visit-media').download(storagePath);
    } catch (_) {
      return null;
    }
  }

  /// Signed URL for media whose local file is gone (e.g. viewed from another
  /// device). Valid for one hour.
  Future<String> signedUrlFor(String storagePath) =>
      _client.storage.from('visit-media').createSignedUrl(storagePath, 3600);

  Future<void> syncPhoto(Photo photo) async {
    try {
      await _uploadPhoto(photo);
    } catch (_) {
      await _enqueue('photos', 'insert', photo.id);
    }
  }

  Future<void> _uploadPhoto(Photo photo) async {
    final path = '$_uid/${photo.visitId}/photo_${photo.id}.jpg';
    // upsert makes retries idempotent when the earlier attempt uploaded the
    // file but failed before the row insert
    await _client.storage.from('visit-media').upload(
          path,
          File(photo.filePath),
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    // no client id: the column is `generated always as identity`, so the
    // server assigns it (a client-sent id would be rejected outright)
    await _client.from('photos').insert({
      'owner_id': _uid,
      'visit_id': photo.visitId,
      'storage_path': path,
      'lat': photo.lat,
      'lng': photo.lng,
      'accuracy_meters': photo.accuracyMeters,
      'captured_at': photo.capturedAt.toUtc().toIso8601String(),
    });
    await (_db.update(_db.photos)..where((p) => p.id.equals(photo.id)))
        .write(PhotosCompanion(storagePath: Value(path)));
  }

  Future<List<VoiceClip>> clipsForVisit(int visitId) => _db.clipsForVisit(visitId);

  /// Saves the clip and returns it immediately. The upload starts right away
  /// (empty transcript) and the clip joins the transcription queue; when its
  /// transcript lands it's pushed to the server separately.
  Future<VoiceClip> saveVoiceClip({
    required int visitId,
    required String filePath,
    required int durationSeconds,
  }) async {
    final id = await _db.insertClip(VoiceClipsCompanion.insert(
      visitId: visitId,
      filePath: filePath,
      durationSeconds: Value(durationSeconds),
    ));
    final clip = await (_db.select(_db.voiceClips)..where((c) => c.id.equals(id))).getSingle();
    unawaited(syncVoiceClip(clip));
    if (transcriber != null && filePath.endsWith('.wav')) {
      _tQueue.add(clip.id);
      _tNotify();
      unawaited(_pumpTranscriptions());
    }
    return clip;
  }

  // ── Transcription queue ─────────────────────────────────────────────────
  // One clip at a time: parallel whisper runs thrash the phone's CPU and make
  // every clip slower. Screens listen to [transcriptionEvents] and re-read
  // [transcriptStateOf] + the clip rows on each bump.
  // ponytail: a native whisper run can't be aborted — "pausing" a running
  // clip discards its result when it lands; that wasted run is the ceiling.

  final transcriptionEvents = ValueNotifier<int>(0);
  final List<int> _tQueue = [];
  final Set<int> _tPaused = {};
  int? _tRunning;
  bool _tDiscard = false;
  bool _tPumping = false;

  void _tNotify() => transcriptionEvents.value++;

  TranscriptState transcriptStateOf(int clipId) {
    if (_tRunning == clipId) return TranscriptState.running;
    if (_tQueue.contains(clipId)) return TranscriptState.queued;
    if (_tPaused.contains(clipId)) return TranscriptState.paused;
    return TranscriptState.none;
  }

  void pauseTranscription(int clipId) {
    if (_tRunning == clipId) {
      _tDiscard = true; // result is dropped when the native run finishes
    } else {
      _tQueue.remove(clipId);
    }
    _tPaused.add(clipId);
    _tNotify();
  }

  void resumeTranscription(int clipId) {
    _tPaused.remove(clipId);
    if (_tRunning == clipId) {
      _tDiscard = false; // caught it before the run finished — keep the result
    } else if (!_tQueue.contains(clipId)) {
      _tQueue.add(clipId);
    }
    _tNotify();
    unawaited(_pumpTranscriptions());
  }

  Future<void> _pumpTranscriptions() async {
    if (_tPumping) return;
    _tPumping = true;
    try {
      while (_tQueue.isNotEmpty) {
        final id = _tQueue.removeAt(0);
        if (_tPaused.contains(id)) continue;
        final clip = await (_db.select(_db.voiceClips)..where((c) => c.id.equals(id))).getSingleOrNull();
        if (clip == null) continue; // deleted while queued
        _tRunning = id;
        _tDiscard = false;
        _tNotify();
        String? text;
        try {
          text = await transcriber?.call(clip.filePath);
        } catch (_) {
          // best-effort: the clip just keeps an empty transcript
        }
        final discarded = _tDiscard;
        _tRunning = null;
        _tDiscard = false;
        if (discarded) {
          _tNotify();
          continue; // paused mid-run: already in _tPaused, result dropped
        }
        if (text != null && text.isNotEmpty) {
          final updated = clip.copyWith(transcript: text);
          await _db.updateClip(updated);
          await _pushTranscript(updated);
        }
        _tNotify();
      }
    } finally {
      _tPumping = false;
    }
  }

  /// Pushes a late-arriving transcript to a server row that was inserted
  /// before transcription finished. Matched by storage_path (the only shared
  /// key — local and server ids differ).
  Future<void> _pushTranscript(VoiceClip clip) async {
    if (clip.storagePath == null) return; // insert replay carries it instead
    try {
      await _client.from('voice_clips').update({'transcript': clip.transcript}).eq('storage_path', clip.storagePath!);
    } catch (_) {
      // offline: transcript is safe locally; a later outbox replay carries it
    }
  }

  /// Removes the clip everywhere: transcription queue, local row + file,
  /// queued sync, and (best-effort) the uploaded copy.
  Future<void> deleteVoiceClip(VoiceClip clip) async {
    _tQueue.remove(clip.id);
    _tPaused.remove(clip.id);
    if (_tRunning == clip.id) _tDiscard = true;
    await (_db.delete(_db.voiceClips)..where((c) => c.id.equals(clip.id))).go();
    final pending = await (_db.select(_db.outbox)..where((o) => o.entity.equals('voice_clips'))).get();
    for (final row in pending) {
      if ((jsonDecode(row.payload) as Map<String, dynamic>)['id'] == clip.id) {
        await (_db.delete(_db.outbox)..where((o) => o.id.equals(row.id))).go();
      }
    }
    try {
      await File(clip.filePath).delete();
    } catch (_) {}
    if (clip.storagePath != null) {
      // ponytail: best-effort remote cleanup — deleting while offline leaves
      // the server copy; add a 'delete' outbox op if that ever matters
      try {
        await _client.storage.from('visit-media').remove([clip.storagePath!]);
        await _client.from('voice_clips').delete().eq('storage_path', clip.storagePath!);
      } catch (_) {}
    }
    _tNotify();
  }

  Future<void> syncVoiceClip(VoiceClip clip) async {
    try {
      await _uploadVoiceClip(clip);
    } catch (_) {
      await _enqueue('voice_clips', 'insert', clip.id);
    }
  }

  Future<void> _uploadVoiceClip(VoiceClip original) async {
    // re-read the row: the transcript may have landed while this upload
    // waited (in-flight or in the outbox) — the insert should carry it
    final clip = await (_db.select(_db.voiceClips)..where((c) => c.id.equals(original.id))).getSingleOrNull() ?? original;
    // extension follows the local file: new clips are wav (whisper-ready),
    // clips recorded before that change are m4a
    final ext = clip.filePath.endsWith('.wav') ? 'wav' : 'm4a';
    final path = '$_uid/${clip.visitId}/clip_${clip.id}.$ext';
    await _client.storage.from('visit-media').upload(
          path,
          File(clip.filePath),
          fileOptions: FileOptions(contentType: 'audio/$ext', upsert: true),
        );
    await _client.from('voice_clips').insert({
      'owner_id': _uid,
      'visit_id': clip.visitId,
      'storage_path': path,
      'duration_seconds': clip.durationSeconds,
      'transcript': clip.transcript,
      'recorded_at': clip.recordedAt.toUtc().toIso8601String(),
    });
    await (_db.update(_db.voiceClips)..where((c) => c.id.equals(clip.id)))
        .write(VoiceClipsCompanion(storagePath: Value(path)));
  }
}
