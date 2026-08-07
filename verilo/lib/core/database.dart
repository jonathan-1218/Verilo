import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ── Tables ───────────────────────────────────────────────────────────────────

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get location => text()();
  TextColumn get district => text()();
  TextColumn get state => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get geofenceMeters => real().withDefault(const Constant(500))();
  TextColumn get sdgTags => text().withDefault(const Constant(''))(); // JSON array
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get budgetCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get reviewInterval => text().withDefault(const Constant('Quarterly'))();
  TextColumn get status => text().withDefault(const Constant('Active'))();
  // CSR reporting fields (Companies Act s.135 annexure). Empty agency means
  // the project is implemented directly by the company.
  TextColumn get implementingAgency => text().withDefault(const Constant(''))();
  TextColumn get csrRegistrationNo => text().withDefault(const Constant(''))();
  IntColumn get beneficiaries => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Visits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get officerName => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get startLat => real().nullable()();
  RealColumn get startLng => real().nullable()();
  RealColumn get gpsAccuracyMeters => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active | complete
  TextColumn get reportHash => text().nullable()(); // SHA-256 of sealed report content
  TextColumn get reportSignature => text().nullable()(); // "keyId:hmac" device seal of reportHash
}

class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get visitId => integer().references(Visits, #id)();
  TextColumn get filePath => text()();
  TextColumn get storagePath => text().nullable()(); // set once uploaded to Supabase Storage
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get accuracyMeters => real().nullable()();
  DateTimeColumn get capturedAt => dateTime().withDefault(currentDateAndTime)();
}

class VoiceClips extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get visitId => integer().references(Visits, #id)();
  TextColumn get filePath => text()();
  TextColumn get storagePath => text().nullable()(); // set once uploaded to Supabase Storage
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get transcript => text().withDefault(const Constant(''))();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
}

class ChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get visitId => integer().references(Visits, #id)();
  TextColumn get label => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class ModelFiles extends Table {
  TextColumn get key => text()(); // 'whisper' | 'gemma'
  TextColumn get filePath => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Queue of writes that failed to reach Supabase (offline). Each row just
/// points at a local id — replaying always re-reads current state from the
/// local table rather than trusting a stale snapshot, so there's only ever
/// one place a row's fields live.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()(); // projects | visits | photos | voice_clips | checklist_items
  TextColumn get op => text()(); // insert | update
  TextColumn get payload => text()(); // JSON: {"id": <local id>}
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Projects, Visits, Photos, VoiceClips, ChecklistItems, ModelFiles, Outbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e); // in-memory executor for tests

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(photos, photos.storagePath);
            await m.addColumn(voiceClips, voiceClips.storagePath);
          }
          if (from < 3) {
            await m.addColumn(visits, visits.reportSignature);
          }
          if (from < 4) {
            await m.createTable(outbox);
          }
          if (from < 5) {
            await m.addColumn(projects, projects.implementingAgency);
            await m.addColumn(projects, projects.csrRegistrationNo);
            await m.addColumn(projects, projects.beneficiaries);
          }
        },
      );

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<List<Project>> allProjects() => select(projects).get();

  Future<int> insertProject(ProjectsCompanion p) => into(projects).insert(p);

  Future<bool> updateProject(Project p) => update(projects).replace(p);

  // ── Visits ────────────────────────────────────────────────────────────────

  Future<List<Visit>> allVisits() => select(visits).get();

  Future<List<Visit>> visitsForProject(int projectId) =>
      (select(visits)..where((v) => v.projectId.equals(projectId))).get();

  Future<int> insertVisit(VisitsCompanion v) => into(visits).insert(v);

  Future<bool> updateVisit(Visit v) => update(visits).replace(v);

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<List<Photo>> photosForVisit(int visitId) =>
      (select(photos)..where((p) => p.visitId.equals(visitId))).get();

  Future<int> insertPhoto(PhotosCompanion p) => into(photos).insert(p);

  // ── Voice clips ───────────────────────────────────────────────────────────

  Future<List<VoiceClip>> clipsForVisit(int visitId) =>
      (select(voiceClips)..where((c) => c.visitId.equals(visitId))).get();

  Future<int> insertClip(VoiceClipsCompanion c) => into(voiceClips).insert(c);

  Future<bool> updateClip(VoiceClip c) => update(voiceClips).replace(c);

  // ── Checklist ─────────────────────────────────────────────────────────────

  Future<List<ChecklistItem>> checklistForVisit(int visitId) =>
      (select(checklistItems)..where((i) => i.visitId.equals(visitId))).get();

  Future<int> insertChecklistItem(ChecklistItemsCompanion i) =>
      into(checklistItems).insert(i);

  Future<bool> toggleChecklistItem(ChecklistItem item) =>
      update(checklistItems).replace(item.copyWith(completed: !item.completed));

  // ── Model files ───────────────────────────────────────────────────────────

  Future<ModelFile?> modelFile(String key) =>
      (select(modelFiles)..where((m) => m.key.equals(key))).getSingleOrNull();

  Future<void> upsertModelFile(ModelFilesCompanion m) =>
      into(modelFiles).insertOnConflictUpdate(m);
}

LazyDatabase _openConnection() => LazyDatabase(() async {
      return driftDatabase(name: 'verilo');
    });
