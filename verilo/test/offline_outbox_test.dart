import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verilo/core/database.dart';
import 'package:verilo/core/repository.dart';

// One check for the offline money path: every Supabase call fails (dead
// endpoint), so writes must land locally, queue in the outbox, and survive
// the merged read paths without being clobbered or dropped.
void main() {
  test('offline writes stay local, queue in outbox, and reads keep them', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = AppRepository(db, SupabaseClient('http://127.0.0.1:1', 'test-key'));

    // create offline → local negative id + outbox entry, still listed
    final project = await repo.createProject(
        name: 'P', category: 'Water', location: 'L', district: 'D', state: 'S');
    expect(project.id, isNegative);
    expect((await repo.allProjects()).map((p) => p.id), contains(project.id));

    // complete a visit offline → completion state survives the read path
    final visit = await repo.startVisit(projectId: project.id, officerName: 'O');
    expect(visit.id, isNegative);
    final ended = await repo.endVisit(visit, notes: 'n', reportHash: 'h', reportSignature: 'k:s');
    expect(ended.status, 'complete');

    final readBack = await repo.visitById(visit.id);
    expect(readBack, isNotNull);
    expect(readBack!.reportHash, 'h'); // not clobbered / dropped by the read
    expect(readBack.notes, 'n');

    // offline checklist toggle keeps completed=true through the read path
    final items = await repo.checklistForVisit(visit.id);
    expect(items, isNotEmpty);
    await repo.toggleChecklistItem(items.first);
    final again = await repo.checklistForVisit(visit.id);
    expect(again.firstWhere((i) => i.id == items.first.id).completed, isTrue);

    // everything above is queued for replay
    final queued = await db.select(db.outbox).get();
    expect(queued.where((o) => o.entity == 'projects' && o.op == 'insert'), hasLength(1));
    expect(queued.where((o) => o.entity == 'visits' && o.op == 'insert'), hasLength(1));
    expect(queued.where((o) => o.entity == 'visits' && o.op == 'update'), hasLength(1));
    expect(queued.where((o) => o.entity == 'checklist_items' && o.op == 'update'), hasLength(1));

    await db.close();
  });
}
