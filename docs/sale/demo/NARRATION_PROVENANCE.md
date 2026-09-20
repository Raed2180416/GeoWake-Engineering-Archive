# Synthetic narration provenance

Generated locally on 20 September 2026 using author model **hexgrad/Kokoro-82M**, stock American English voice **af_heart**, CPU inference. No person-specific voice cloning, fine-tuning, or reference recording was used. The narration is editorial explanation, not the developer's personal recording and not evidence of the app's audible alarm output.

Official sources checked 20 September 2026:

- Model and license declaration: https://huggingface.co/hexgrad/Kokoro-82M — Apache-2.0; the author describes commercial deployment of the Apache-licensed model.
- Inference library and license: https://github.com/hexgrad/kokoro and https://github.com/hexgrad/kokoro/blob/main/LICENSE — Apache-2.0.
- Apache License 2.0 text: https://www.apache.org/licenses/LICENSE-2.0

A dated local copy of the official model card is `../render/Kokoro-model-card-2026-09-20.md`. Library license text is `../render/Kokoro-library-LICENSE`. Downloaded model repository revision: `f3ff3571791e39611d31c381e3a41a3af07b4987`. Model and voice SHA-256 receipts are in `model-checksums.sha256`; dependency versions are in `requirements-receipt.txt`. Downloaded files originate from the author's Hugging Face repository and reside in `../.models/kokoro/`. Packages came from PyPI, the official PyTorch CPU index, and spaCy's official model release. The standalone model repository LICENSE URL returned 404; license evidence is its explicit Apache-2.0 model-card metadata, not an invented downloaded license file.

All eight narration clips were generated at Kokoro speed 1.0. No post-generation speech acceleration was applied. Each fits its existing video window, so the 112-second visual edit was preserved. Clips start 0.1 seconds after their chapter's beginning. Two-pass loudness normalization targets -16 LUFS and a -1.5 dBTP peak ceiling. No music or artificial alarm effect was inserted.

`generation-receipt.json` stores input text, pronunciation override, predicted token timings and clip lengths. `audio-timing-validation.json` confirms that clips finish before their chapter ends and contain finite, nonzero samples. The supplied aligned SRT uses model-predicted token times; it is a usable generated transcript, not independently forced-aligned speech recognition.

Audio sample inspection was attempted through the available audio tool output, which explicitly reported that this agent does not support audio input. Therefore no claim of perceptual listening or human voice-quality approval is made. The clips and sample MP3 remain available for playback; signal/timing checks, ffmpeg loudness analysis and full media decoding provide automated checks.

No source video, private recording or narration text was uploaded to an external generation service. Fish Audio generation was not used for this commercial buyer demo. No purchase or subscription was made.

## Archived-corpus framing revision

The final narration section was regenerated to reflect the developer’s clarified offer: archived code and engineering history for AI training and software engineering evaluation. The developer’s reason for stopping is primary-source testimony about underground calibration dataset collection cost; no stop date or visual proof of sensor fusion is claimed. Unchanged sections 1–7 reuse their original local audio; no new product work is offered. Superseded product-framing media is retained privately in `../private-superseded-product-framing/` and is not a shareable deliverable.
