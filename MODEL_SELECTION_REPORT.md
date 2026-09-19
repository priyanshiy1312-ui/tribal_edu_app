# Model & Architecture Selection Report — BhashaMitra

This document explains two deliberate engineering decisions made during development, and why each was chosen over the alternative.

---

## 1. Whisper Base Model, Chosen Over Tiny / Larger Variants

BhashaMitra runs Whisper fully on-device (via `flutter_whisper_ggml`) to keep the classroom experience offline. This forces a real accuracy-vs-speed tradeoff, since the model has to run on standard classroom tablet hardware, not a server GPU.

We evaluated the three practical options:

- **Whisper tiny** — fastest, lowest memory footprint, but noticeably worse transcription accuracy on natural, sometimes noisy classroom speech. Given that our downstream fuzzy-matching step already has to tolerate phrasing variation, adding ASR-level noise on top of that risked compounding errors and pushing match accuracy down further.
- **Whisper base** *(chosen)* — a meaningfully better accuracy/latency balance for on-device inference. It still runs within an acceptable time budget on the target hardware while producing noticeably cleaner Hindi transcriptions than tiny.
- **Whisper small/medium/large** — better accuracy in principle, but the on-device inference time and memory requirements were not viable for a low-cost classroom tablet running fully offline. These were ruled out early as impractical for this deployment target, not tested to completion.

**TODO (Person 3):** If Person 2 has formal benchmark numbers (accuracy %, transcription latency in seconds per model, tested on the actual target device), insert them here as a small table. If no formal benchmark exists, leave this section as the qualitative reasoning above — do not invent numbers.

```
| Model  | Approx. inference time | Transcription quality (qualitative) |
|--------|------------------------|--------------------------------------|
| tiny   | TODO                   | TODO                                  |
| base   | TODO                   | TODO                                  |
| small+ | Not viable on-device    | Not tested to completion              |
```

**Conclusion:** Whisper base was chosen as the best available balance of accuracy and on-device latency for the target classroom hardware, given that any further latency cost compounds into the already-above-target end-to-end pipeline time.

---

## 2. Closed-Set Phrase Matching, Chosen Over Open-Domain NMT Translation

Rather than attempting open-ended Hindi→Santali machine translation, BhashaMitra matches recognized speech against a fixed, curated set of 56 classroom phrases. This was a deliberate scope decision, not a fallback for a missing feature:

1. **Latency and reliability on real classroom hardware.** Closed-set matching against a small, indexed phrase list is fast and deterministic. Open-domain NMT — especially for a low-resource language pair — would add unpredictable inference cost and failure modes to a pipeline that is already above its latency target.

2. **Santali is a low-resource language for NMT.** High-quality Hindi↔Santali translation models are not mature, and there was no reliable way to QA open-domain translation output for correctness within the sprint timeframe. Shipping unreliable, unreviewable translations in a live classroom is a worse outcome than a smaller, correct, verified phrase set.

3. **The actual use case doesn't need open-ended translation.** PALASH's classroom instructional vocabulary is itself largely fixed — a small set of recurring instructions ("sit down," "open your books," "line up," etc.). A closed, curated, human-verified phrase set covers the real target use case directly, without the risk profile of general-purpose translation.

**Conclusion:** Closed-set matching trades unbounded vocabulary coverage for guaranteed correctness and predictable latency — the right tradeoff for a live classroom tool serving young students in a low-resource language, within a hackathon sprint timeframe. Open-domain NMT is flagged as explicit future work (see README §10) once the vocabulary and QA process can support it.