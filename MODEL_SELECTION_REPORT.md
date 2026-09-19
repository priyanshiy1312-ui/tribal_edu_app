# Model Selection Report — BhashaMitra

This document explains two deliberate engineering decisions behind BhashaMitra's architecture: the choice of Whisper model size, and the choice of closed-set phrase matching over open-domain translation.

---

## 1. Speech Recognition: Whisper `base` model

BhashaMitra uses OpenAI's Whisper model, running fully on-device via `flutter_whisper_ggml`, to transcribe the teacher's spoken Hindi.

**Why `base`, not `tiny` or a larger model:**

- We directly compared `tiny` and `base` on-device during development. **`tiny` was faster, but its Hindi transcription accuracy was noticeably worse** — it missed and misrecognized more words than `base` did in our hands-on testing. Given that transcription accuracy directly determines whether the downstream phrase matcher can succeed at all, this made `tiny` a poor fit despite its speed advantage: a faster but wrong transcription is worse than a slightly slower correct one, since the matcher has no way to recover from bad input text.
- **Larger models** (`small`, `medium`, and above) would likely improve accuracy further, but at a real cost: longer load times, higher memory usage, and slower inference — all of which matter on the kind of budget Android tablets this project targets for real classroom deployment (not high-end devices). Given our current end-to-end latency is already a known area for improvement, a larger model would make that worse, not better; we did not test these larger sizes given this tradeoff.
- **`base`** was chosen as the practical middle point based on this comparison: meaningfully better Hindi transcription accuracy than `tiny`, while staying light enough to run acceptably on-device without cloud infrastructure — which is a hard requirement for the offline classroom use case, not a nice-to-have.

This is a defensible tradeoff for the target hardware and offline constraint, not an arbitrary default.

## 2. Translation Approach: Closed-set phrase matching, not open-domain NMT

BhashaMitra does **not** perform open-ended machine translation of arbitrary Hindi sentences into Santali. Instead, it matches recognized speech against a fixed, curated list of 56 classroom phrases, each with a pre-translated Santali equivalent.

**Why this, deliberately, rather than open-domain NMT:**

- **Guaranteed offline reliability.** Every phrase's Santali translation and audio is prepared ahead of time, during an online SYNC phase. The live classroom experience never depends on a translation model running correctly in real time — it only needs to match text against a known list and play back audio that's already sitting on the device. This removes an entire class of failure modes (model errors, unexpected output, translation quality varying by sentence) from the part of the system a teacher actually depends on mid-lesson.
- **Santali is a low-resource language for machine translation.** Reliable, high-quality Hindi-to-Santali NMT is not a solved problem the way major-language pairs are. Deploying open-domain translation for a real classroom tool, without the ability to properly validate translation quality across arbitrary sentences in the time available, would risk delivering incorrect or nonsensical Santali to students — a worse outcome than a narrower but reliable tool.
- **The PALASH curriculum use case is naturally bounded.** Classroom instruction language (sit down, open your notebook, listen carefully, etc.) is repetitive and predictable. A curated, growable phrase list directly matches how the tool is actually used, rather than solving a more general problem the use case doesn't require.
- **Latency and predictability.** Fuzzy-matching against a local list is fast and has bounded, predictable performance. An NMT model's inference time and output quality both vary more unpredictably, which matters for a tool meant to be used continuously through a live lesson.

This tradeoff was made consciously, not because NMT access wasn't attempted — see the README's Bhashini Integration section for how the team pursued additional API access during this sprint, including specifically for Santali. Open-domain NMT support remains a natural direction for future work once translation quality for Santali can be properly validated.