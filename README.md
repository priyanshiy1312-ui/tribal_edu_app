# BhashaMitra - Sahyog

**Offline Hindi-to-Santali classroom translation for Jharkhand's PALASH programme.**

SIH26042 | Smart India Hackathon | Government of Jharkhand

---

## Problem Statement

Jharkhand's PALASH programme places Hindi-speaking teachers in classrooms where students speak Santali, a tribal language written in the Ol Chiki script. Teachers have no way to bridge this language gap in real time — especially in classrooms with no reliable internet access.

## Solution Overview

BhashaMitra uses a two-phase architecture designed specifically for **offline, real-time classroom use**:

- **Phase 1 — SYNC** (ahead of time, when internet is available): a fixed set of 56 common classroom phrases are translated from Hindi to Santali and their audio is cached locally on the tablet.
- **Phase 2 — CLASSROOM** (fully offline): the teacher speaks a Hindi instruction, an on-device Whisper model transcribes it, the recognized text is fuzzy-matched against the 56 cached phrases, and the matched phrase's Santali audio plays back — no internet required, no round-trip delay to a server.

This is a deliberate **closed-set matching** design, not open-domain translation — see [`MODEL_SELECTION_REPORT.md`](./MODEL_SELECTION_REPORT.md) for why.

```
Teacher taps mic
  → records Hindi speech (auto-stops on ~1.2s silence)
  → on-device Whisper (base model) transcribes to Hindi text
  → fuzzy-matched against 56 cached phrases (confidence threshold ~0.45)
  → matched phrase's cached Santali audio plays back
  → recognized Hindi + matched Santali text shown on screen
```

## Key Features

- **Fully offline classroom operation** — no internet needed once phrases are synced
- **On-device speech recognition** — Whisper (base model) running locally, no server round-trip
- **Resilient fuzzy phrase matching** — handles natural rephrasing (e.g. "aap khade ho" vs. "khade ho jao") via combined character-similarity and word-overlap scoring, not just exact matches
- **Classroom-scale audio** — teacher's tablet pairs with a shared Bluetooth speaker at the OS level, so no per-student hardware is needed
- **Match analytics logging** — every recognition attempt is logged locally for accuracy tracking and debugging

## Tech Stack

| Component | Technology |
|---|---|
| App framework | Flutter (Dart) |
| Local database | `sqflite` |
| Speech recognition | `flutter_whisper_ggml` (on-device Whisper, base model) |
| Audio recording | `record` (WAV, 16kHz, mono) |
| Audio playback | `audioplayers` |
| Phrase matching | `string_similarity` + custom token-overlap scoring |
| Phrase data | `csv` |
| TTS (audio generation) | Bhashini API (see note below) |

## Current Status

Honest, current numbers as of this build:

- **Phrase set**: 56 curated classroom phrases (Hindi, romanized Hindi, Santali in Ol Chiki script)
- **Translation source**: cross-checked against NCERT reference materials; not yet verified by a native Santali speaker — flagged here rather than overstated
- **Audio coverage**: 14 of 56 phrases currently have real Santali audio bundled; remaining phrases are being filled in
- **Match accuracy**: actively being measured and improved (a fuzzy-matching upgrade was made during this sprint to better handle natural phrasing variation); a clean benchmark will be published once audio coverage is complete
- **Latency**: end-to-end pipeline (recording stop → transcription → match → playback) currently runs several seconds — above our real-time target, and the next optimization priority

## Bhashini API Integration

We requested and received approved access to Bhashini's TTS and NMT services for this project, specifically to auto-generate the remaining Santali audio files.

During integration, we found that our granted access is provisioned against AI4Bharat's Coqui-TTS models (covering 15 languages), which does not currently include Santali — even though Bhashini's own public service catalog separately lists Santali TTS support through other providers (IIT Madras's `Bhashini/IITM/TTS`, and Bodhan.AI's `bhashini/bodhan/indic-tts`). We verified this directly via the Bhashini pipeline API rather than assuming: querying for Santali TTS models returns no available service for our current grant.

We've reached out to Bhashini to request access to these specific services. In the meantime, this gap doesn't block the core product, since our architecture pre-caches all audio during the offline SYNC phase — audio coverage will continue to grow as we add manually-sourced recordings and as broader Bhashini access becomes available.

Supporting evidence (approval confirmation and follow-up correspondence) is available in [`docs/bhashini-evidence/`](./docs/bhashini-evidence/).

## Classroom Deployment Model

BhashaMitra is designed for **one tablet per classroom**, paired with a shared, inexpensive Bluetooth speaker (paired at the Android OS level — no app changes required). This avoids the cost of per-student hardware while still making the translated audio audible to the whole class.

## Setup & Running

```bash
flutter pub get
flutter run
```

Requires Flutter 3.47+ and an Android device/emulator (tested on API 28, x86_64).

## Team

Team BhashaMitra — Smart India Hackathon, SIH26042, for the PALASH programme, Government of Jharkhand.

## Future Work

- Full Bhashini TTS integration once Santali-supporting services are accessible
- Native-speaker verification of all Santali translations
- Open-domain NMT support for phrases beyond the curated 56, once translation resources allow
- Latency optimization (profiling which pipeline stage dominates end-to-end time)
- Expanded phrase coverage for broader classroom scenarios