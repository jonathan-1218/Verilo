# Verilo — Implementation Brief for Claude Code

You are working in the existing Verilo Flutter repo. The Flutter project lives in the
`verilo/` subdirectory (that is where `pubspec.yaml`, `lib/`, `android/`, `ios/` are).
Run all `flutter` commands from inside `verilo/`.

Do NOT re-architect. Match the existing patterns:
- Singletons live in `lib/core/app_scope.dart`.
- All Supabase reads/writes go through `lib/core/repository.dart`, which mirrors into
  the drift DB defined in `lib/core/database.dart`.
- Supabase is source of truth; drift is the offline cache. Writes go to Supabase first,
  fall back to drift on failure.
- Colors/text styles are in `lib/core/colors.dart` and `lib/core/text_styles.dart`.
- Routing is GoRouter in `lib/core/router.dart`.

Work through the tasks IN ORDER. After each task: run `flutter analyze` (0 errors) and
`flutter run` on the Android emulator to confirm the app still launches. Do one task,
confirm it works, then move to the next. Do not batch them.

Do NOT touch or re-enable the commented-out ML packages (`whisper_flutter_new`,
`flutter_gemma`, lines ~65–66 of pubspec.yaml) unless a task explicitly says so.

---

## TASK 1 — Upload photo & voice-clip bytes to Supabase Storage (highest priority)

**Problem:** Right now `repository.dart` only syncs row metadata. The actual JPEG and
M4A files never leave the device, so a second device sees photo/clip rows with no media.
The `visit-media` storage bucket and the `storage_path` columns already exist in
`supabase/schema.sql`.

**Do this:**
1. In `repository.dart`, change `syncPhoto(Photo photo)` so it:
   - Uploads the local file at `photo.filePath` to the `visit-media` bucket using
     `_client.storage.from('visit-media').upload(path, File(photo.filePath))`.
   - Use an object path scoped by user and visit, e.g.
     `'${_uid}/${photo.visitId}/photo_${photo.id}.jpg'`.
   - After a successful upload, include `'storage_path': path` in the row insert that
     already happens, and also write `storage_path` back into the local drift row.
   - Keep the existing offline behavior: if upload OR insert throws, swallow it and leave
     the row local-only (unchanged filePath), so it retries on next sync.
2. Do the same for `syncVoiceClip(VoiceClip clip)` using the local `clip.filePath`
   (extension `.m4a`, path `'${_uid}/${clip.visitId}/clip_${clip.id}.m4a'`).
3. Add a read helper so screens can display remote media when the local file is gone:
   `Future<String> signedUrlFor(String storagePath)` that returns
   `_client.storage.from('visit-media').createSignedUrl(storagePath, 3600)`.
4. Confirm `database.dart` photos/voice_clips tables have a nullable `storagePath` text
   column. If not, add it, then regenerate drift code:
   `dart run build_runner build --delete-conflicting-outputs`.

**Acceptance:** Capture a photo + record a clip on the emulator, confirm files appear in
the Supabase `visit-media` bucket under `<user-id>/<visit-id>/`, and confirm the
`photos`/`voice_clips` rows have a non-null `storage_path`.

---

## TASK 2 — Cloud transcription fallback (Deepgram Nova-3, opt-in)

**Problem:** Voice clips have empty transcripts (on-device Whisper is deferred), so the
app shows "Transcript unavailable". Add an opt-in cloud fallback so transcription works
now, without re-enabling any native ML package.

**Do this:**
1. Add a `TranscriptionService` in `lib/services/transcription_service.dart`:
   - Method `Future<String?> transcribe(String filePath)`.
   - POST the audio file bytes to Deepgram's prerecorded API
     (`https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true`) using the
     existing `dio` dependency, with header `Authorization: Token <DEEPGRAM_API_KEY>`
     and `Content-Type: audio/m4a`.
   - Parse `results.channels[0].alternatives[0].transcript` from the JSON response.
   - Return null on any error (offline / no key / bad response). Never throw.
2. Read the key from env: add `DEEPGRAM_API_KEY` to `.env.example` and load it via the
   existing `flutter_dotenv` setup. If the key is empty, `transcribe` returns null
   immediately (feature simply off).
3. Gate it behind an opt-in flag stored in `shared_preferences`
   (key `cloud_transcription_enabled`, default false). Only call Deepgram when true.
4. Wire it into the flow: after `saveVoiceClip` in `repository.dart` succeeds, if the
   opt-in flag is on, call the transcription service, and on a non-null result update the
   clip's `transcript` both in Supabase (`voice_clips.transcript`) and in drift.
5. Register `TranscriptionService` as a singleton in `app_scope.dart`.

**Acceptance:** With the flag on and a valid key, recording a clip fills its transcript
within a few seconds, visible in `visit_capture_screen`. With the flag off or no key, the
app behaves exactly as before (no crash, empty transcript).

---

## TASK 3 — Real cryptographic sealing of the PDF report

**Problem:** `pdf_service.dart` (see the `ponytail` comment near line 78) only computes a
sha256 hash. The product promises hardened, tamper-evident capture. Add device-backed
signing of the report hash.

**Do this:**
1. Add the `flutter_secure_storage` package (backed by Android Keystore / iOS Keychain).
2. On first run, generate an app key pair OR generate/store a per-install secret; sign the
   report's sha256 digest so the PDF carries: the sha256 hash AND a signature + a stable
   device/key identifier.
   - Simplest robust version: keep a persistent random signing secret in secure storage,
     and compute an HMAC-SHA256 of the report digest with it. Include
     `hash`, `hmac`, and a short `key_id` on the PDF's seal footer.
3. In `pdf_service.dart`, extend the seal section to render all three values
   (use the existing monospace style / copper theme, keep it compact at the bottom).
4. Return the hmac alongside the existing `(filePath, hash)` tuple, and persist it on the
   visit row (add a nullable `report_signature` column to both `schema.sql` and
   `database.dart`; regenerate drift; store it in `endVisit`).

**Acceptance:** Generating a report produces a PDF whose footer shows hash + signature +
key id, and the `visits` row stores both `report_hash` and `report_signature`.

---

## TASK 4 — Replace the faked AI summary

**Problem:** `report_screen.dart` (~line 47) passes `visit.notes` as `aiSummary`, so the
"AI Summary" in the PDF is just the raw notes.

**Do this (pick the path that matches what's enabled):**
- If cloud transcription (Task 2) is on and there are transcripts, generate a short
  summary by sending the combined transcripts + notes to a summarization call. Keep it
  behind the SAME opt-in cloud flag from Task 2. Put this in a new
  `SummaryService.summarize(List<String> transcripts, String notes)` returning a
  2–4 sentence string; return the raw notes as fallback when cloud is off.
- Do NOT re-enable `flutter_gemma`. On-device summary stays deferred.
- Update `report_screen.dart` to call `SummaryService` and pass its result as `aiSummary`.

**Acceptance:** With cloud on, the PDF "AI Summary" reads as a real summary of the visit;
with cloud off, it falls back to notes exactly as today (no regression).

---

## TASK 5 — Make offline sync reliable (outbox queue)

**Problem:** `repository.dart` admits it has no outbox and no conflict resolution: offline
writes are only retried when some screen happens to re-read that list (last-write-wins).
This is unsafe for multi-officer commercial use. (PowerSync is in the plan but is NOT in
pubspec — do NOT add PowerSync in this task; build a lightweight outbox that fits the
current architecture.)

**Do this:**
1. Add a drift table `outbox` in `database.dart`: `id`, `entity` (projects/visits/photos/
   voice_clips/checklist_items), `op` (insert/update), `payload` (JSON text),
   `local_ref` (nullable, to reconcile server-assigned ids), `created_at`. Regenerate
   drift.
2. In every write method in `repository.dart`, when the Supabase call throws (offline),
   enqueue the operation into `outbox` instead of silently dropping it.
3. Add `Future<void> flushOutbox()` that replays queued ops oldest-first when online,
   removing each row on success and stopping on the first failure (stay offline-safe).
4. Call `flushOutbox()` on app resume and on successful auth, from `app_scope` / the
   dashboard load. Keep last-write-wins for now but make it deliberate, not accidental.

**Acceptance:** Turn off the emulator network, create a project + start a visit + capture a
photo, turn network back on, trigger a resume — the queued items appear in Supabase and
the outbox empties.

---

## TASK 6 — Add the missing Model Download screen (screen 3 in the design spec)

**Problem:** The design spec lists a Model Download screen; `lib/screens` has no
`model_download_screen.dart`. `ModelService` already exists to download Whisper/Gemma.

**Do this:**
1. Build `model_download_screen.dart` matching the design tokens (charcoal + copper,
   Space Grotesk, progress bar in `copperLight`). Show each model (Whisper, Gemma),
   its ready state via `ModelService.isReady`, size, and a download button wired to
   `ModelService.download` with the progress callback.
2. Add the route in `router.dart`. Make it reachable but OPTIONAL (these models are the
   deferred premium on-device path) — e.g. from a settings/profile entry, not blocking
   the main flow.
3. Do not auto-run the models yet; this screen only manages the files.

**Acceptance:** Screen renders, shows model status, and a download shows live progress and
flips the state to ready when complete.

---

## TASK 7 — Cleanup / verification pass

1. Confirm iOS `ios/Runner/Info.plist` `CFBundleURLSchemes` contains
   `com.verilo.verilo` (Android manifest already has the `login-callback` deep link).
   Add it if missing.
2. Confirm the Supabase URL Configuration has the redirect
   `com.verilo.verilo://login-callback` (this is a dashboard setting, flag it to the
   user if you can't verify from code).
3. Ensure `.env.example` lists ALL required keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `DEEPGRAM_API_KEY`. Do not commit real secrets; `.env` stays gitignored.
4. Run `flutter analyze` and `flutter test`; fix anything red.

---

## Notes / guardrails
- Never hardcode API keys — always read from `.env`.
- Keep every network call offline-safe: catch, degrade, never crash the capture flow
  (camera/mic/GPS must always work offline).
- After each task, stop and report what changed + the acceptance result before continuing.
