# BhashaMitra – Sahyog

*Real-time Hindi→Santali classroom bridge, built for Jharkhand's PALASH programme.*

<!-- Add team/project logo here: ![BhashaMitra Logo](assets/logo.png) -->

---

## 1. Problem Statement

Jharkhand's PALASH programme aims to deliver primary education in students' mother tongues, but most teachers posted in tribal-belt schools speak Hindi and do not know Santali (Ol Chiki script). Existing translation tools assume internet connectivity and general-purpose translation quality — neither of which is reliable in the rural classrooms where this gap matters most. BhashaMitra – Sahyog lets a Hindi-speaking teacher deliver a fixed set of core classroom instructions in Santali, entirely offline, with a single tap.

## 2. Solution Overview

BhashaMitra works in two phases:

- **Phase 1 – SYNC (done ahead of time, online):** A curated set of 56 fixed classroom phrases (e.g. "sit down", "open your books", "line up") is translated from Hindi to Santali — both text and audio — using the Bhashini API, and cached locally on the tablet.
- **Phase 2 – CLASSROOM (fully offline):** The teacher speaks the Hindi phrase naturally. An on-device Whisper model transcribes it, the transcription is fuzzy-matched against the 56 cached phrases, and the matched phrase's pre-generated Santali audio plays back instantly through the classroom speaker — no internet required.

This split is deliberate: it moves all the unreliable, connectivity-dependent work (translation quality, API calls) to before the school day starts, so the classroom experience itself is fast, predictable, and offline-first.

## 3. Key Features

- **Offline-first classroom mode** — zero connectivity required once phrases are synced
- **On-device ASR** — Whisper (base model) runs locally, no audio leaves the device
- **Fuzzy phrase matching** — handles natural variation in how a teacher phrases a request
- **Bluetooth speaker classroom scaling** — one tablet + one shared Bluetooth speaker serves the whole room, no per-student hardware
- **Bhashini TTS integration** — real Santali audio generation for the phrase set
- **Match analytics logging** — every match attempt (recognized text, matched phrase, confidence score, hit/miss) is logged locally for later review

## 4. Tech Stack

| Layer | Technology |
|---|---|
| App framework | Flutter (Dart), 3.47.2-stable |
| Local database | sqflite (`phrases` + `match_logs` tables) |
| CSV parsing | csv ^6.0.0 |
| File paths | path, path_provider |
| Fuzzy matching | string_similarity ^2.2.0 |
| On-device ASR | flutter_whisper_ggml ^0.0.2 (Whisper base model) |
| Audio recording | record ^7.1.1 (WAV, 16kHz, mono) |
| Permissions | permission_handler ^13.0.2 |
| Audio playback | audioplayers ^6.8.1 |
| Santali TTS | Bhashini API |

## 5. Architecture / How It Works

```
Teacher taps mic
   │
   ▼
Records Hindi speech (auto-stop after ~1.2s silence, 8s hard cap)
   │
   ▼
Whisper (on-device, base model) → transcribes to Hindi text
   │
   ▼
PhraseMatcherService fuzzy-matches text against 56 phrases in SQLite
   (string_similarity, confidence threshold ~0.45)
   │
   ├── Match found ──► AudioService plays cached Santali audio
   │                    (assets/audio/<phrase.id>.aac)
   │                    → routed through paired Bluetooth speaker
   │
   └── No match ─────► UI signals no match, teacher can retry
   │
   ▼
UI displays recognized Hindi text + matched Santali text
   │
   ▼
Match attempt logged to match_logs (text, phrase, score, hit/miss)
```

**Classroom deployment:** a single tablet paired with a shared Bluetooth speaker at the OS level — no app-level changes needed, since `audioplayers` routes through whatever output device is active. This keeps hardware cost to one tablet + one speaker per classroom, rather than per-student devices.

## 6. Model Selection Rationale

See [MODEL_SELECTION_REPORT.md](./MODEL_SELECTION_REPORT.md) for the reasoning behind two deliberate engineering choices: using the Whisper **base** model over tiny/larger variants, and using **closed-set phrase matching** instead of open-domain NMT translation.

## 7. Current Status / Honest Metrics

We're presenting real numbers, not aspirational ones — the gaps below are known, prioritized, and being actively worked on.

- **Latency:** ~6–12 seconds end-to-end (recording stop → transcription → match → playback), varying with phrase length and device load. This is above the problem statement's <3s target. Known optimization target — see Future Work.
- **Phrase coverage:** 49 / 56 phrases loading correctly *(provisional — a known CSV-parsing bug was causing this; confirm with Person 2 closer to submission whether it's since been fixed)*.
- **Audio coverage:** *(provisional — pending final count from Person 2 of how many phrases have real Bhashini-generated Santali audio vs. placeholder/missing)*.
- **Match accuracy:** ~50% recognition success in testing *(provisional — Person 2 has been improving fuzzy-matching logic to handle phrasing variation, e.g. "khade ho jao" vs "aap khade ho"; confirm final number before submission)*.

## 8. Setup / How to Run

**Requirements:** Flutter 3.47.2-stable, a device or emulator with microphone access.

```bash
# 1. Clone the repo
git clone https://github.com/priyanshiy1312-ui/tribal_edu_app.git
cd tribal_edu_app

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

> Note: microphone permission is required at runtime for Phase 2 (classroom mode) to function. On first launch, grant mic access when prompted.

## 9. Team & Acknowledgments

Built for **Smart India Hackathon 2026**, problem statement **SIH26042**, on behalf of the **Government of Jharkhand's PALASH programme** for mother-tongue-based primary education.

<!-- TODO: add team name and member names/roles here -->

## 10. Future Work

- **Open-domain NMT** — move beyond the fixed 56-phrase set toward general Hindi↔Santali translation, once low-resource NMT quality for Santali can be reliably QA'd
- **Expanding the phrase set** — grow beyond 56 phrases as the PALASH curriculum's instructional vocabulary grows
- **Latency optimization** — closing the gap from ~6-12s toward the <3s target (model quantization, streaming transcription, warm-start optimizations)
- **Multi-language support** — extending the same SYNC/CLASSROOM architecture to other tribal languages beyond Santali

---

*BhashaMitra is deliberately scoped as a closed-set, offline-first tool. It does not include login/auth, LAN broadcast, or multi-device sync in this version — these were conscious scope cuts to keep the classroom experience fast and reliable within the sprint timeframe.*
