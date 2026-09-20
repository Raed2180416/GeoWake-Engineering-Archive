# GeoWake archived engineering corpus — narration script

Target: 112 seconds. Calm, clear, interested stock synthetic narrator; warm delivery without sales hype. Do not clone or imply the developer's personal voice. Pronounce GeoWake “jee-oh wake”. Generate sections independently to fit the windows; leave small pauses at cuts. The video is also usable silently with its chapter captions.

| Cut time | Narration |
|---|---|
| 00:00–00:08 | Meet GeoWake: a destination alarm app built by a solo developer, shown here in a controlled Android demo. |
| 00:08–00:20 | Choose a destination, then set when you would like to be alerted. This example uses a metro stop threshold before the journey starts. |
| 00:20–00:36 | The app displays the route, estimated time remaining, and distance to destination. Beside it, the developer dashboard feeds a simulated journey into the demo. |
| 00:36–00:52 | Speed and time controls make route scenarios easier to inspect. This edit skips waiting time, while keeping the setup, tracking, transfer notice, and arrival alert visible. |
| 00:52–01:04 | As the simulated journey approaches a transfer, an Upcoming transfer notification appears, with controls to stop the alarm or end tracking. |
| 01:04–01:17 | Near the destination, a Wake Up notification appears. The recording shows the visual alert state; its original audio track contains no audible alarm. |
| 01:17–01:34 | A second excerpt shows Map Tracking in dark mode, with a road route and the same time, distance, and end-tracking controls. These are recorded interface demonstrations. |
| 01:34–01:52 | GeoWake's archived codebase is offered for AI training and evaluation. Its history includes route tracking, sensor fusion experiments, and regression tests. Development stopped because collecting underground calibration data became too costly. |

## Audio handling

The supplied MP4 has an AAC track, but ffmpeg volumedetect reports mean and peak levels of -91.0 dB (digital silence). The captioned cut includes a silent AAC track for compatibility. Do not add an alarm effect and represent it as recorded behavior. A narration version, if generated, must clearly identify synthetic narration in the delivery notes.

## Claim limits

The offer concerns an archived codebase and engineering history for AI training and software engineering evaluation. It does not include product continuation or further development. Solo-developer status, repository contents, and the reason work stopped (impractical underground-calibration dataset collection cost) come from the developer/task brief, not the pixels. No stop date is inferred. Sensor fusion work is not claimed to be demonstrated by this recording. The demonstrated build's commit is unidentified. The source container creation metadata is 2026-01-15T12:05:10Z; this is metadata, not independently authenticated recording provenance. Edit date: 20 September 2026.
