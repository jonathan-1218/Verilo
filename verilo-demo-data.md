# Verilo — Demo Data Sheet

Everything below matches the app's input forms field-for-field. Log in with
your own email (OTP arrives via Resend), then enter these in order.

## 1. Profile setup

| Field | Value |
|---|---|
| Full name | Arjun Mehta |
| Date of birth | 14/03/1991 |
| Company / Organisation | Tata Steel CSR |

## 2. Projects (create all three)

### Project A — WASH
| Field | Value |
|---|---|
| Project name | Nandgram School WASH |
| Category | WASH |
| SDG tags | SDG3, SDG6 |
| Description | Drinking water purification and sanitation blocks for the Nandgram Zilla Parishad school, covering 340 students. |
| Site name | Nandgram Village School |
| District | Raigad |
| State | Maharashtra |
| Geofence radius | 500m |
| Start date | 01/04/2026 |
| End date | 31/03/2027 |
| Review interval | Quarterly |
| Budget (₹) | 1200000 |

### Project B — Education
| Field | Value |
|---|---|
| Project name | Digital Classrooms Salem |
| Category | Education |
| SDG tags | SDG4, SDG8 |
| Description | Smart-board classrooms and teacher training across 6 government high schools in Salem block. |
| Site name | GHS Ammapet |
| District | Salem |
| State | Tamil Nadu |
| Geofence radius | 250m |
| Start date | 15/06/2026 |
| End date | 15/06/2028 |
| Review interval | Monthly |
| Budget (₹) | 4500000 |

### Project C — Environment
| Field | Value |
|---|---|
| Project name | Miyawaki Urban Forest Pune |
| Category | Environment |
| SDG tags | SDG13, SDG17 |
| Description | 2-acre Miyawaki plantation with 12,000 native saplings on reclaimed municipal land, maintained with the PMC horticulture department. |
| Site name | Baner Hill Plot 7 |
| District | Pune |
| State | Maharashtra |
| Geofence radius | 1km |
| Start date | 05/07/2026 |
| End date | 05/07/2029 |
| Review interval | Biannual |
| Budget (₹) | 800000 |

## 3. Visits

Start a visit from a project's detail page. The 5-item checklist is seeded
automatically. Suggested actions per visit:

**Visit 1 — Nandgram School WASH.** Check 4 of 5 checklist items (leave
"Pipeline integrity scan" unchecked). Take 2 photos, record one short voice
note ("Water tanks installed and chlorination log is up to date; pipeline
scan pending vendor visit."). Notes field:
> RO plant commissioned and dispensing. Girls' sanitation block 80% complete — tiling pending. Headmaster requests soap dispenser refills monthly.

**Visit 2 — Digital Classrooms Salem.** Check all 5 items. One photo.
Notes:
> All 6 smart boards operational. 14 of 18 teachers completed training module 2. Projector in Room 4 flickers — replacement raised with vendor.

**Visit 3 — Miyawaki Urban Forest Pune (offline test).** Turn on **airplane
mode first**, then run the whole visit: start it, check 3 items, write notes,
end the visit and open the report — everything should work and seal locally.
Then turn airplane mode off and pull up the dashboard: the visit, checklist
ticks, notes, and seal should appear in Supabase within a few seconds.
Notes:
> Survival rate 91% after first monsoon. Drip lines need repair on the north slope. PMC gardener attendance regular.

## 4. Things to verify while running

- End a visit → open its report → note the SHA-256 / HMAC in the integrity
  seal → close and reopen the report: **the seal must not change**.
- On-device models screen: flip **Cloud fallback** on only if a
  `DEEPGRAM_API_KEY` is set in the bundled .env; otherwise leave it off
  (voice notes then just keep an empty transcript).
- The dashboard "visits this month" tile should count all three visits.
