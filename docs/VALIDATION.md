# Validation status

Development machine: Apple silicon, macOS 26.6.2, Xcode 26.6 / Swift 6.3.3. Deployment target: macOS 14. This does not establish compatibility with every intermediate OS or MacBook.

## Completed

- Native Swift debug and release builds.
- Four core unit tests: report validation, angle mapping endpoints/monotonicity, 60/120 Hz spring agreement, and reversal/settling bounds.
- Production Metal renderer export and visual inspection of the open, partial-fold and closed states. Public PNG/GIF assets contain a synthetic desktop only.
- Real-GPU checks for source preservation at the open endpoint, black at the closed endpoint, and position-dependent loss of detail.
- Hardware sensor discovery and valid angle reports on the development Mac. The app explicitly reports its polling compatibility fallback when no input events arrive.
- Native settings window launch and visual inspection.
- Ad-hoc app bundle signing and signature verification.

## Still needs physical/user validation

- Screen Recording authorization and a full live desktop session, including overlay exclusion under sustained capture.
- Moving the physical lid through slow, fast and reversed folds while recording synchronized angle and frame traces.
- Sleep/wake, secure/locked sessions, display changes and Escape under active capture.
- macOS 14/15 and other MacBook sensor generations; prolonged GPU load, thermal impact and battery usage.
- Quantitative matching to reference footage. Camera perspective and missing angle traces prevent an exact parameter fit.

The release is a preview. Passing unit and GPU checks does not establish end-to-end latency, physical animation fidelity, or compatibility across hardware.

## 0.1.1 frame pacing

Replaced the live 60 Hz run-loop timer with an NSScreen CADisplayLink and use elapsed time in the preview spring. The live surface requests the screen’s maximum refresh rate; screen capture remains capped at 60 Hz. Duplicate sensor values/statuses no longer trigger SwiftUI publications. This addresses pacing weaknesses identified in code; the reported three-step physical effect has not yet been reproduced or confirmed fixed. Core and GPU checks pass.
