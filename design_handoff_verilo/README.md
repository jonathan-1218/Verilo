# Handoff: Verilo — CSR Field Audit App

## Overview

Verilo is a privacy-first, offline-first CSR (Corporate Social Responsibility) field audit and reporting app for Android (primary), iOS, and Web. CSR officers visit project sites, capture geo-tagged photos, record voice memos (transcribed on-device by Whisper), and generate cryptographically sealed PDF audit reports — all without any data leaving the device unencrypted.

**Tagline:** Every visit. On record.

---

## About the Design Files

The files in this bundle are **high-fidelity design references created in HTML** — interactive prototypes showing the intended look, content, and behaviour of every screen. They are **not production code to ship directly**.

Your task is to **recreate these designs in Flutter** (the target stack specified in the build spec) using its established patterns (BLoC, drift, GoRouter, GetIt). The HTML prototypes are the source of truth for visual design; the build spec document is the source of truth for architecture and data.

Use the screen navigator row below the phone frame in `Verilo.dc.html` to jump between all 12 screens instantly.

---

## Fidelity

**High-fidelity.** Every screen is pixel-complete with final colours, typography, spacing, component states, and copy. Recreate the UI as closely as possible in Flutter, adapting only for platform conventions (e.g. `TextFormField` vs a custom div, `ListView` vs a scroll div).

---

## Design Tokens

### Colour Palette — Charcoal + Copper

| Token | Hex | Usage |
|---|---|---|
| `copperDark` | `#8C5020` | Gradient start, deep accent |
| `copperMid` | `#B87040` | Primary buttons, active states, FABs |
| `copperLight` | `#D08848` | Progress bars, highlights, cursor blink |
| `copperGlow` | `#D4956A` | Subtle tinted text on dark bg |
| `bgDeep` | `#0D0B09` | Outer shell / system bg |
| `bgApp` | `#1E1B18` | App-level screen background |
| `bgCard` | `#252220` | Card / surface |
| `bgCardElevated` | `#2A2420` | Elevated card (info panels, summaries) |
| `bgPlaceholder` | `#2E2A26` | Image placeholders, map tiles |
| `navBar` | `#141210` | Bottom navigation bar |
| `textPrimary` | `#EDE8E3` | Main body text, headings |
| `textSecondary` | `#9A8F88` | Labels, descriptions |
| `textMuted` | `#5C5550` | Tertiary, timestamps, placeholders |
| `borderSubtle` | `rgba(255,255,255,.07)` | Card borders, dividers |
| `amber` | `#D08848` | Warnings, pending status |
| `amberBg` | `rgba(200,120,48,.12)` | Warning tinted backgrounds |
| `red` | `#D44040` | Destructive, recording active |
| `blue` | `#4880C8` | Active / synced status |

### Typography

| Role | Font | Size | Weight | Notes |
|---|---|---|---|---|
| App logo | Space Grotesk | 28–50px | 700 | `veri` in copper, `lo` in white |
| Screen title | Space Grotesk | 15px | 700 | |
| Section heading | Space Grotesk | 18px | 700 | Wizard step titles |
| Card title | Space Grotesk | 14–15px | 600 | |
| Body | Space Grotesk | 12–13px | 400 | |
| Label (uppercase) | Space Grotesk | 9–11px | 600 | `letter-spacing: 1px`, `text-transform: uppercase` |
| Monospace values | JetBrains Mono | 9–12px | 400–500 | GPS coords, hashes, timestamps |
| Stat numbers | Space Grotesk | 22px | 700 | Dashboard stat cards |

### Spacing & Shape

| Token | Value |
|---|---|
| Screen padding | 18px horizontal |
| Card border-radius | 14–16px |
| Chip border-radius | 20px (fully rounded) |
| Input border-radius | 12px |
| Avatar border-radius | 50% |
| Card gap | 10–14px |
| Section gap | 16–18px |

### Shadows (iOS-style, subtle on dark bg)

- Card: `box-shadow: 0 1px 4px rgba(0,0,0,.35)`
- FAB: `box-shadow: 0 6px 20px rgba(184,112,64,.45)`
- Primary button: `box-shadow: 0 4px 16px rgba(184,112,64,.3)`

---

## Screens & Views

### 1. Splash Screen

**Purpose:** Brand moment + device setup check (models present, auth state).

**Layout:** Full-screen centred flex column. Dark warm gradient background (`#141210 → #1E1A14 → #2A2018`). Subtle grid overlay at 1px / 40px intervals `rgba(255,255,255,.015)`.

**Components:**
- Logo: `veri` in `#D4956A` 50px/700, `lo` in `#FFFFFF` 50px/700, `letter-spacing: -1.5px`
- Tagline: `EVERY VISIT. ON RECORD.` — 11px, `letter-spacing: 4px`, `rgba(255,255,255,.4)`
- Pulsing GPS dot: 8px circle `#D4956A` with `ping` animation (scale 1→2.5, opacity 0.6→0, 1.8s infinite)
- "Checking device setup…" label: 12px, `rgba(255,255,255,.35)`
- "Continue →" ghost button: bottom 32px, `rgba(255,255,255,.3)`

**Behaviour:** Auto-advances to Onboarding after 2.5s. "Continue →" skips immediately.

---

### 2. Onboarding (3 pages)

**Purpose:** First-run walkthrough explaining GPS evidence, voice-to-report, and privacy.

**Layout:** White-ish bg (`#F2F7F0` equivalent, but use `#1E1B18` in the dark theme). Flex column. Top: Skip button right-aligned. Middle: Illustration area (282px tall, `#2E2A26` bg with hatched pattern) + headline + body text. Bottom: Dot indicators + CTA button.

**Pages:**
1. "Evidence that holds up" — GPS crosshair SVG
2. "Voice to verified report" — animated waveform bars
3. "Private by design" — shield SVG with checkmark

**Dot indicator:** Active dot `#B87040` at 22px wide, inactive dots `rgba(0,0,0,.12)` at 6px wide. Transition: `width 0.35s ease`.

**Waveform animation (page 2):** 9 bars, 4px wide, `#D08848`, each using `wv1/wv2/wv3/wv4` keyframes staggered 0.08s. Heights oscillate between 5–36px.

**CTA button:** Full width, `border-radius: 14px`, bg `#B87040`, white text 16px/700. Label "Next →" on pages 0–1, "Get Started →" on page 2.

---

### 3. Model Download Screen

**Purpose:** One-time download of Whisper (~600MB) + Gemma (~700MB) models.

**Layout:** Padding 28px. Title + subtitle. Amber warning pill. Two progress cards. Footer note. "Skip for demo →" ghost link.

**Warning pill:** `background: rgba(200,120,48,.12)`, `border: 1px solid rgba(200,120,48,.25)`, amber 6px dot with pulse animation, text in `#A86800`.

**Progress cards:** `bg #252220`, `border-radius: 14px`, padding 18px. Header row: model name (14px/600) + percentage (13px/700 `#B87040`). Progress bar: 5px tall, bg `#2E2A26`, fill `linear-gradient(90deg, #8C5020, #D08848)`. Footer: `JetBrains Mono` 10px `#5C5550` showing `XXX MB / 600 MB`.

**Behaviour:** Both bars animate simultaneously. On completion, auto-navigate to Login after 0.9s.

---

### 4. Login Screen

**Purpose:** Email magic link or Google OAuth sign-in.

**Layout:** Padding 44px top, 26px sides. Logo at top. Heading + subtitle. Email input field. Primary CTA. Divider. Secondary Google button. Footer note.

**Email input:** `bg #252220`, `border: 1.5px solid rgba(184,112,64,.35)`, `border-radius: 12px`, padding 13px 16px. Shows pre-filled demo email with a blinking cursor (`width: 2px`, `height: 17px`, `#D08848`, pulse animation). On focus: `box-shadow: 0 0 0 4px rgba(184,112,64,.06)`.

**Primary button:** Full width, `bg #B87040`, white text 15px/700, `border-radius: 14px`, `box-shadow: 0 4px 16px rgba(184,112,64,.3)`.

**Google button:** `bg #252220`, `border: 1.5px solid rgba(255,255,255,.1)`, text `#EDE8E3`.

---

### 5. Dashboard

**Purpose:** Officer home — stats overview, project list or map view.

**Layout:** Flex column. Optional offline banner at top. Scrollable content area. Bottom nav (56px, `#141210`). Active tab indicator: 2.5px bar in `#C87941`.

**Offline banner:** `bg rgba(200,120,48,.12)`, `border-bottom: 1px solid rgba(216,138,10,.2)`. Amber 6px dot + "Offline — saving visits locally" in `#A86800`. Right-aligned "3 pending" count.

**Header row:** "Good morning" 12px `#9A8F88` + officer name 20px/700. Hamburger avatar button 38px circle `#252220` with border.

**Stat cards (3 cols):** `bg #252220`, `border-radius: 12px`, padding 14px 10px. Stat number 22px/700 (green/amber/white). Label 10px `#9A8F88`, 2 lines.

**List / Map toggle:** `bg #2A2420`, `border-radius: 20px`, padding 3px. Active pill: `bg #B87040`, white text 11px/700. Inactive: transparent, text `#476058`.

**Project cards (List view):** `bg #252220`, `border-radius: 16px`, padding 14px. Image placeholder 76px tall with hatched pattern. Category chip (copper or blue). SDG tags. Status badge. Progress bar (4px, `#D08848` or `#13BA78`).

**Map view:** SVG Maharashtra map (`bg #2A2218` with grid lines, state outline `#332A20`). Two animated project pins — green `#B87040` for active, amber `#D08848` for review-due. Floating info cards above pins with `mapFloat` animation (translateY 0→-3px, 3s infinite). Legend card bottom-right. Location list rows below the map.

**New Project FAB:** `position: absolute`, `bottom: 70px`, `right: 18px`. Copper bg, white text, "＋ New Project". `box-shadow: 0 6px 20px rgba(184,112,64,.45)`.

---

### 6. Create Project Wizard (4 steps)

**Purpose:** Collect all project parameters before creating a project. Accessed via the "New Project" FAB.

**Layout:** Sticky header (back + title + step badge). 3px progress bar. Scrollable form area. Sticky bottom CTA (Back + Next/Create).

**Progress bar:** Fill `linear-gradient(90deg, #8C5020, #D08848)`, width 25% / 50% / 75% / 100% per step. Transition `width 0.35s ease`.

**Step badge:** `bg rgba(184,112,64,.12)`, copper text, `border-radius: 20px`, shows "1 / 4".

**Step 1 — Basic Info:**
- Project name input: active-bordered input with blinking cursor
- Category selector: pill chips, selected = `bg #B87040` white text, unselected = `bg #252220` muted border
- Schedule VII clause: dropdown row
- SDG tags: same pill chip pattern (multi-select)
- Description: multiline text area, min-height 68px

**Step 2 — Location:**
- 148px map preview with GPS ping animation and auto-detected coordinate badge
- Site name input (active)
- District + State side-by-side inputs
- Geofence radius pill selector (250m / 500m / 1km / Custom)

**Step 3 — Timeline & Budget:**
- Start / End date pickers (side-by-side, calendar icon)
- Review interval pill selector (Monthly / Quarterly / Biannual / Annual)
- Budget input with ₹ prefix and blinking cursor
- Auto-calculated summary card: Duration, No. of reviews, Budget per month

**Step 4 — Team + Summary:**
- Assigned members list: 36px avatar + name + role + "LEAD" badge or "Remove" button
- "Add team member" dashed border button
- Read-only Project Summary card (all collected params) with copper accent border

**Back button:** Shown from step 2 onwards. `bg #252220`, muted text, left-arrow.
**Next button (steps 1–3):** "Next →", copper bg.
**Final CTA (step 4):** "Create Project ✓", navigates to Project Detail.

---

### 7. Project Detail

**Purpose:** Overview of a single project — metadata, process list, activity status.

**Layout:** Header (back + title + "Info" button). Scrollable content. Start Visit FAB. Bottom nav.

**"Info" button:** `bg #2A2420`, `border: 1px solid rgba(255,255,255,.1)`, copper text, ℹ icon, navigates to Project Parameters screen.

**Tags row:** SDG chips (copper), status chip (blue), category chip (muted).

**Budget card:** `bg #252220`, `border-radius: 12px`. Budget left, period right.

**Process rows:** `bg #252220`, `border-radius: 14px`. Header: process name + due date (amber) + status badge. Expanded: activity list.

**Activity states:**
- Completed: 18px green circle with checkmark, text struck-through in `#5C5550`
- Active (in-progress): pulsing ring animation, `bg rgba(184,112,64,.05)`, `border: 1px solid rgba(184,112,64,.16)`, copper accent text
- Pending: empty circle `border: 1.5px solid #3A3028`, muted text

**Start Visit FAB:** `position: absolute`, bottom 14px right 0. Copper bg, `border-radius: 24px`. `box-shadow: 0 6px 20px rgba(184,112,64,.4)`.

---

### 8. Project Parameters (Info View)

**Purpose:** Read-only display of all project parameters. Accessed via "Info" button in Project Detail header.

**Layout:** Header (back + title + subtitle). Scrollable sections with consistent card pattern.

**Section card pattern:** `bg #252220`, `border-radius: 14px`, overflow hidden. Header: 12px padding 16px, `border-bottom: 1px solid rgba(255,255,255,.06)`. Icon (SVG) + label 11px/700 copper uppercase. Body: 14px padding 16px, rows of label (12px `#5C5550`) + value (12px/600 `#EDE8E3`).

**Sections:** Timeline, Budget, Location, Intervention, Team.

**Progress bars in Timeline/Budget:** 5px, gradient copper fill.

**Team members:** 32px avatar (gradient or muted), name + role, "YOU" copper badge for current user.

---

### 9. Visit Setup (GPS Lock)

**Purpose:** GPS acquisition before starting a visit. Officer sees live accuracy.

**Layout:** Header (back + title). 220px map preview. GPS status card. Warning box. Two bottom CTAs.

**Map:** Same SVG Maharashtra pattern. GPS ping animation at screen centre: two concentric rings with `ping` keyframe + central 14px dot `#D08848` with glow.

**GPS status card:** `bg #252220`. Row: pulsing dot + "GPS acquiring" + accuracy value in amber. 5px progress bar (gradient amber→copper). Method label.

**Warning box:** `bg rgba(200,120,48,.06)`, `border: 1px solid rgba(200,120,48,.15)`. Triangle warning SVG + amber text.

**CTAs:** "Start Visit Now" (full width, copper). "Cancel" (outline, muted).

---

### 10. Visit Capture — Variant A (Tabbed)

**Purpose:** Main field data capture UI. Tabbed layout with Photos, Voice, Checklist, Notes.

**Layout:** Sticky white header (dark in this theme: `#252220`). Tab bar. Scrollable pane per tab. No bottom nav (active visit context).

**Header:** Visit name + project name. Timer (JetBrains Mono 15px/700 copper). "End" button (`bg rgba(212,64,64,.12)`, `border: 1px solid rgba(212,64,64,.2)`, red text). GPS chip (copper bg tint). TAB / SCROLL toggle.

**Tab bar:** 4 tabs. Active: 2px bottom border copper, copper text 11px/600. Inactive: transparent border, muted text. `border-bottom: 1px solid rgba(255,255,255,.07)` on container.

**Photos pane:**
- "Take Photo" button: dashed copper border, `bg rgba(184,112,64,.07)`
- 2×2 grid of photo thumbnails: hatched pattern placeholder, "GPS" badge (copper bg, white text), coordinate + time overlay at bottom
- Empty slots: dashed `rgba(255,255,255,.1)` border

**Voice pane:**
- 88px circular hold-to-record button. Idle: copper gradient, mic SVG. Recording: red gradient `#D44040`, same mic. Shadow pulses on recording: `0 0 0 16px rgba(212,64,64,.15)`.
- 12 waveform bars animate when recording (`opacity: 1` vs `0.25` idle), colour `#D08848`
- Transcript card: `bg #252220`, "TRANSCRIPT" label + "Whisper" badge. Body text `#EDE8E3`.
- **Saved clips** (appear after each hold-release): `bg #2A2420`, `border-radius: 12px`. Mic icon circle + "Clip N" + timestamp + duration + "SAVED" copper badge. Transcript preview below divider.

**Checklist pane:**
- Completed items: 18px green-bg checkbox square (`#13BA78` in green theme, adapt to copper: use `#B87040`) with white checkmark, text struck-through in `#9A8F88`
- Pending items: `border: 1.5px solid #3A3028`, text `#EDE8E3`

**Notes pane:** Multiline editable area, `bg #252220`, min-height 150px. "Auto-saved HH:MM AM" right-aligned 10px `#5C5550`.

---

### 11. Visit Capture — Variant B (Single Scroll)

**Purpose:** Alternative layout — all sections on one page, no tabs. Officer can scroll through everything.

**Layout:** Same sticky header. Scrollable single column. Sections: Photos strip → Voice recorder → Checklist → Field Notes. Sticky "End Visit & Generate Report" CTA at bottom (gradient fade).

**Photo strip:** Horizontal scroll of 76×76px thumbnails + empty-slot placeholder.

**Voice recorder (compact):** 48px mic button + "Hold to record" + clip count. Transcript preview below divider.

**Sticky CTA:** `position: absolute`, bottom 0, full width. Gradient `transparent → #1E1B18`. Copper button.

---

### 12. Report Preview

**Purpose:** Review the generated PDF before downloading or sharing.

**Layout:** Header (back + "Report Ready" + "Share" outline button). Scrollable PDF card. Download + Home action buttons.

**PDF card:** `bg white`, `border-radius: 16px`, `box-shadow: 0 4px 20px rgba(0,0,0,.1)`.
- Header bar: `bg #B87040` (copper), white "Site Visit Report", copper-tinted "verilo" logo
- Sections with 1px dividers: Project Details, Visit Information, Geo-Verified Photos, Field Notes, Integrity Verification
- Each section: 8px label UPPERCASE `#9A8F88`, table of key/value pairs (10px, label `#6B7280`, value `#111827` 600 weight)
- Photo thumbnails: 4:3 aspect ratio, hatched placeholder, dark overlay with monospace timestamp
- Integrity section: `bg #F5F5F4`, SHA-256 hash in `JetBrains Mono`

**Action buttons:** "Download PDF" (copper, flex:1) + "Home" (white outline bg, muted text) side by side.

---

## Interactions & Behaviour

| Trigger | Action |
|---|---|
| Splash auto-timer 2.5s | Navigate to Onboarding |
| Onboarding "Next →" (3×) | Step through pages, then → Model Download |
| Model Download progress | Auto-navigate to Login on 100% |
| Login "Send Magic Link" | Navigate to Dashboard |
| Dashboard project card tap | Navigate to Project Detail |
| Dashboard "New Project" FAB | Navigate to Create Wizard step 1 |
| Create Wizard "Next →" | Advance step, update progress bar |
| Create Wizard "Create Project ✓" | Navigate to Project Detail |
| Project Detail "Info" | Navigate to Project Parameters |
| Project Detail "Start Visit" FAB | Navigate to Visit Setup |
| Visit Setup "Start Visit Now" | Navigate to Capture A |
| Capture A/B "End" / "End Visit" | Navigate to Report Preview |
| Dashboard hamburger icon | Toggle offline banner |
| Dashboard List / Map toggle | Switch between list and map view |
| Voice tab: hold mic button | `isRecording = true`, red state |
| Voice tab: release mic button | Save clip to `savedClips[]`, show in UI |
| TAB / SCROLL toggle | Switch capture layout variant |
| Report "Home" | Navigate to Dashboard |

### Animations

| Name | Keyframes | Usage |
|---|---|---|
| `fadeIn` | opacity 0→1, translateY 6→0px | Screen transitions |
| `slideUp` | opacity 0→1, translateY 14→0px | Wizard step content |
| `pulse` | opacity 1→0.3→1 | GPS dot, cursor blink |
| `ping` | scale 1→2.5, opacity 0.6→0 | GPS rings, project pin rings |
| `wv1/2/3/4` | height oscillates 5–36px | Voice waveform bars |
| `mapFloat` | translateY 0→-3px→0 | Map info cards floating |

---

## State Management

```dart
// Key state variables (BLoC / Cubit recommended)

// Navigation
String screen; // 'splash' | 'onboarding' | 'login' | 'dashboard' | 'create_project' | 'project_detail' | 'project_params' | 'visit_setup' | 'visit_capture' | 'report'

// Onboarding
int onboardingPage; // 0–2

// Model download
double whisperProgress; // 0.0–1.0
double gemmaProgress;   // 0.0–1.0

// Dashboard
String dashView; // 'list' | 'map'
bool showOffline;

// Create project wizard
int createStep; // 0–3

// Visit capture
String captureVariant; // 'A' (tabbed) | 'B' (scroll)
String activeTab;       // 'photos' | 'voice' | 'checklist' | 'notes'
bool isRecording;
List<VoiceClip> savedClips;
int visitTimer; // seconds elapsed, increments every 1s during active visit
```

---

## Assets

| Asset | Source | Notes |
|---|---|---|
| Space Grotesk font | Google Fonts | Weights 400, 500, 600, 700 |
| JetBrains Mono font | Google Fonts | Weights 400, 500 |
| Maharashtra SVG map | Hand-drawn in prototype | Recreate as a Flutter `CustomPainter` or embed as SVG asset |
| GPS / mic / shield icons | Inline SVG in prototype | Extract from `Verilo.dc.html` or replace with Flutter icon equivalents |
| Whisper model | HuggingFace ggerganov/whisper.cpp | `ggml-large-v3-turbo-q5_0.bin` ~600MB, download on first launch |
| Gemma model | HuggingFace lmstudio-community | `gemma-3-1b-it-Q4_K_M.gguf` ~700MB, download on first launch |

---

## Files in This Bundle

| File | Purpose |
|---|---|
| `Verilo.dc.html` | Main interactive prototype — all 12 screens, fully navigable |
| `android-frame.jsx` | Android device bezel component (design scaffolding only, not needed in Flutter) |
| `README.md` | This document |

---

## Implementation Notes for Flutter

1. **Fonts:** Add `space_grotesk` and `google_fonts` packages, or bundle the fonts in `assets/fonts/`.

2. **Colours:** Define all tokens in `lib/core/constants/app_colors.dart` using the hex values in the Design Tokens section above.

3. **Navigation:** Use `GoRouter` (already in the spec). Map each `screen` string to a named route.

4. **Bottom nav:** Use a `BottomNavigationBar` with `backgroundColor: Color(0xFF141210)`, selected item indicator via a 2.5px `Container` above the label.

5. **Map view:** Use `MapLibre GL` with offline tiles (already specified in tech stack). Overlay custom `Marker` widgets for project pins with the floating card animation.

6. **GPS ping animation:** Use `AnimationController` with `CurvedAnimation(parent: controller, curve: Curves.easeOut)` driving `ScaleTransition` + `FadeTransition` on a `Container` with `border-radius: 50%`.

7. **Voice waveform:** Animate bar heights using `AnimationController` with `Tween<double>` for each bar, staggered by `interval` on the controller.

8. **Hold-to-record:** Use `GestureDetector` with `onLongPressStart` / `onLongPressEnd` (or `onTapDown` / `onTapUp` for walkie-talkie feel).

9. **Progress bar (wizard):** `AnimatedContainer` with `width` transition, `duration: Duration(milliseconds: 350)`, `curve: Curves.easeInOut`.

10. **Saved clips:** Each clip is a `VoiceClip` model with `id`, `timestamp`, `durationSeconds`, `transcript`. Add to a `List` in the visit BLoC state on recording stop.
