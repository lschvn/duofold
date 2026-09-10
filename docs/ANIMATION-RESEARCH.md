# iPhone Duo fold animation and its macOS adaptation

## Findings

The reference effect is best understood as an optical continuity illusion. During a fold, a moving display appears to become a sheet of diffusing glass over a second image. The apparent distance between the sheet and that image changes across the display. Some content remains identifiable near the hinge while content farther away loses detail. Geometry, defocus, shading, and the handoff between displays work together; a uniform blur or a rotating screenshot captures only part of the effect.

A MacBook cannot literally reproduce the complete transition: it has no second display on its keyboard or lid exterior, and a third-party macOS application cannot rearrange every other application's internal UI. DuoFold therefore applies the observable optical cues to one captured desktop, with the bottom edge as the hinge. This is an independent recreation, not Apple's implementation, and the constants below are engineering choices rather than recovered Apple parameters.

## Video evidence

The following references were inspected as timestamped frames, including independently located footage. Times identify useful portions of each source, not a proposed fixed animation duration. All footage was published in September 2026 or supplied as a contemporaneous reference. Downloaded research copies and contact sheets are excluded from the public repository; links preserve access to the originals.

| Reference | Useful interval | Direct observation | Limitation |
|---|---|---|---|
| Apple, [iPhone Duo: Everything announced](https://www.youtube.com/watch?v=ZlMvbjknrIg&t=181s) | 3:01–3:07 | Lock Screen closes from a wide inner image to an outer image. The moving portion darkens and blurs progressively while recognizable clock and landscape content persist. | Promotional footage, no sensor trace or camera calibration. |
| Apple, [same presentation](https://www.youtube.com/watch?v=ZlMvbjknrIg&t=354s) | 5:54–5:57 | A faster closing demonstration preserves visual continuity through the change of visible display. | Cannot infer end-to-end latency from edited footage. |
| The Tech Chap, [iPhone Duo Hands-On!](https://www.youtube.com/watch?v=XRKjMvfYV0o&t=9s) | 0:09–0:15 | Closing becomes strongly defocused, then sharp again when closed; opening reveals a blurred left region that clears as the device flattens. Around 12.85–13.90 s, the right Home Screen remains legible while the moving left side resolves. | Oblique handheld camera; physical and software transforms overlap. |
| Marques Brownlee, [iPhone 18 Pro/Duo Impressions: Mogged](https://www.youtube.com/watch?v=Od6M0AXpcxQ&t=348s) | 5:48–5:55 | Slow opening and a small reversal retain image continuity. A soft region on the moving half resolves into the widget layout by roughly 353.4 s. | Video frame rate and camera exposure limit timing precision. |
| Marques Brownlee, [same video](https://www.youtube.com/watch?v=Od6M0AXpcxQ&t=614s) | 10:14–10:30 | Repeated opening/closing shows the effect following hinge movement rather than completing a preset playback after every trigger. Closed content becomes sharp again. | Qualitative responsiveness evidence, not an instrumented latency result. |
| Numerama, [Expectation VS reality iPhone Duo](https://www.facebook.com/Numerama/videos/expectation-vs-reality-iphone-duo/2043404643022720/) | 0:00–0:04 and 0:05–0:17 | Comparison of promotional and physical-device footage. Strong localized blur appears during both directions; the stationary region stays more readable. | Edited comparison; the two sequences do not share angle/time calibration. |
| [User-supplied YouTube close-up](https://www.youtube.com/shorts/uJdjKOBikTE) | 0:02–0:05 and 0:07–0:09 | At extracted time 2.479 s, the outer display has legible shapes at one edge and much broader diffusion farther across it. At 3.972 s, related content appears on both sides of the moving boundary. | Creator identity was not established from the supplied URL; attribution is to the video itself. |
| Apple, [product-page hero](https://www.apple.com/iphone-duo/) | Embedded hero, approximately 1.9–2.8 s | During opening, the photo/widget region remains blurred before resolving while the app grid is already readable. | A short, composed product shot. |

The independently located hands-on sequences corroborate the supplied clips. The effect is present on a physical device, not solely in Apple's promotional animation. Apple's developer design material separately describes continuity across the two displays and layout adaptation around the fold, but does not publish the compositor shader, blur curve, spring constants, or exact activation angles.[1][2]

## Separating the visual components

### Spatial defocus

The blur has position-dependent strength. It cannot be reproduced by applying a single Gaussian radius to the entire image. A uniform blur makes the whole desktop look out of focus simultaneously, losing the impression that one edge remains close to the underlying content.

For a single bottom hinge, define normalized image coordinates `(u, v)`, where `v = 0` is the top/free edge and `v = 1` is the hinge. Distance from the hinge is `d = 1 - v`. The initial implementation uses `amount = progress^0.85 × d^1.2 × blurStrength`. The target sigma is 54 times this amount, capped at the strongest prefiltered level. Both powers are tunable interpretation, not measurements. The product of an angle term and a spatial term ensures that the open endpoint is sharp and the hinge remains the least blurred region.

Three prefiltered textures with approximate Gaussian sigmas of 2.5, 9, and 28 pixels at a 1600-pixel reference width provide a smooth spatial mixture with the original image. The native capture width scales those sigmas proportionally. This avoids a conspicuous, sparse multi-tap blur and keeps the filter stable when the lid stops. Apple documents that `MPSImageGaussianBlur` is an optimized Gaussian approximation, not an analytically exact convolution.[3]

Mixing a small set of blurred levels is also an approximation to a continuously variable point-spread function. It is a practical starting point, not evidence of Apple's technique. The renderer retains the sharp original for the zero-blur endpoint. Additional levels would be justified if inspection reveals blur bands or inconsistent edge spread.

### Projection and image continuity

The footage contains three transforms at once: the physical display moving in space, the camera projecting that surface, and software changing the displayed content. Treating their combined movement as a shader deformation would double-count the physical rotation on a real laptop.

The Mac adaptation therefore uses restrained perspective, not an exaggerated page curl. A bottom-anchored projective grid narrows and foreshortens the desktop gradually. Homogeneous vertex coordinates preserve perspective-correct texture interpolation. A small continuous curvature term softens the otherwise rigid plane; its amplitude is an artistic Mac adaptation and is not established as part of Apple's compositor.

The phone can change from mirrored Home Screen content to a different widget region. A captured Mac desktop supplies only one scene, so DuoFold must preserve that scene. It does not invent another desktop, mirror text, move windows in their owning applications, or pretend that content continues onto the keyboard. The rendered overlay is temporary; actual window positions stay where they were.

### Light and darkening

The observed moving region often darkens near an edge or at a grazing angle. Some of that comes from the panel, reflections, and camera exposure. It would be incorrect to bake every observed shadow into the software effect.

The implementation provides mild angle-dependent shading that increases toward the free edge, plus a restrained highlight. Shade emphasizes darkening; Frost emphasizes diffusion and a modest cool veil; Silk keeps a softer balance. These are independently designed presets inspired by the supplied app concept, not identified Apple modes.

A Mac has no visible outer screen to receive the image when shut. Its final closing phase fades to black before the system sleeps. This is a macOS adaptation; the phone footage instead ends with a sharp outer screen. DuoFold does not prevent system sleep or render over the secure login screen.

### Timing and reversibility

The user's hand controls the animation's progress. A two-second demonstration does not imply a two-second software animation. Reversing the lid halfway must reverse the visual state immediately; holding a partial angle must retain that state. Blur should track angle, not angular velocity, because the reference resembles changing optical separation rather than camera motion blur.

The implementation maps an adjustable clear angle to zero progress and a near-closed angle to full progress. A short critically damped filter interpolates sensor quantization between render frames. Its closed-form solution preserves continuity when retargeted and does not depend on refresh rate. The default response parameter is 55 ms; this is a model parameter, not a measured latency or a promise that all settling finishes in 55 ms.

Apple's spring-animation session explains why velocity-preserving retargeting produces continuous motion and why springs need not bounce.[4] An adaptive low-pass alternative is the One Euro filter, which trades less jitter at low speed for less lag at high speed.[5] Stacking both filters without measurements would add unnecessary lag. The initial app uses one temporal filter and exposes response for calibration.

## Hardware and capture design

A local probe on the development Mac found the Apple HID orientation collection, opened it without elevated privileges, received feature report bytes `[1, 109, 0]`, and received an input-value event for usage page `0x20`, usage `0x047f`, angle `109`. This establishes sensor access on this machine, not compatibility with all Apple silicon Macs. The application matches vendor `0x05ac`, usage page `0x20`, collection usage `0x8a` and validates the angle range.

The original LidAngleSensor project identifies the undocumented sensor interface and its feature-report decoding.[6] The local descriptor and probe also support an input-event path. The app prefers events and has an explicitly labeled 60 Hz feature-report compatibility fallback when events are not delivered. The sensor is undocumented even though IOKit's HID functions are public APIs. Compatibility must be checked by probing, not inferred solely from the processor name.

ScreenCaptureKit captures only the built-in display. Its filter excludes the entire DuoFold process to prevent recursive self-capture. Complete frame buffers become Metal textures; capture errors, blank frames, sleep, or display changes clear the overlay. No audio capture is requested and no desktop frames are written to disk or uploaded. Apple describes both content filtering and IOSurface-backed capture buffers in its ScreenCaptureKit material.[7][8]

Protected content can be unavailable in capture. Screen Recording permission is required. The system permission prompt remains a user action; the app must show actionable instructions and remain usable in sample-preview mode before permission is granted. An unsigned/ad-hoc development build is not a notarized public distribution.

## Calibration and acceptance

“Perfect” requires a defined reference, a viewing position, and measurements. Handheld internet footage cannot establish exact lens parameters, physical hinge angles, sensor-to-photon delay, or Apple's proprietary rendering coefficients. The correct engineering target is consistent observable behavior with explicitly bounded differences.

| Area | Acceptance condition | Verification method |
|---|---|---|
| Open endpoint | No residual blur, tint, scale, or offset | Compare a synthetic calibration image with shader progress zero, then hide the overlay at rest. |
| Hinge anchoring | The bottom edge does not translate as progress changes | Render a grid through an angle sweep; inspect the bottom row and corners. |
| Spatial blur | Defocus grows toward the free edge; no abrupt bands | High-contrast text/grid fixture, fixed intermediate angles. |
| Reversal | No restart, snap, or queued completion after changing direction | Synthetic triangular angle traces and physical partial reversals. |
| Frame-rate consistency | Same motion state at the same elapsed time at 60 and 120 Hz | Numerical tests of the continuous-time filter. |
| Near-closed behavior | Fade and system sleep without a lingering desktop overlay | Physical close/open cycle, including a fast close. |
| Capture safety | No hall of mirrors, no external-display overlay, immediate restoration on failure | Permission denial/revocation, disconnect, sleep/wake, and stream-stop tests. |
| Performance | No sustained frame backlog | Bounded in-flight commands; profile actual sensor/capture/GPU timing on target hardware. |

For quantitative visual matching, film the Mac and reference device with a fixed camera, mark display corners, rectify each screen plane with a homography, and align sequences by physical angle rather than wall time. Measure edge-spread width at several normalized distances from the hinge, landmark displacement, and luminance. Fit blur, projection, and shading separately. Do not report physical degrees recovered from a single uncalibrated handheld shot.

The public demo images must use original synthetic content so they can be inspected for visual quality without disclosing a real desktop. They demonstrate the actual Metal shader but cannot replace physical hinge testing or establish exact equivalence to iPhone Duo.

## Sources

1. Apple. [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo). September 2026. Display continuity, fold-aware layout and reserved regions.
2. Apple Design. [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/). Tech Talks, September 2026. Device poses and adaptive layout principles.
3. Apple. [MPSImageGaussianBlur](https://developer.apple.com/documentation/metalperformanceshaders/mpsimagegaussianblur). API reference, accessed September 10, 2026. Approximate Gaussian filtering and precision.
4. Apple. [Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/). WWDC23. Retargeting, velocity continuity and damping.
5. Géry Casiez, Nicolas Roussel, Daniel Vogel. [1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems](https://gery.casiez.net/1euro/). CHI 2012. Adaptive jitter/lag tradeoff.
6. Sam Henri Gold. [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor), particularly [LidAngleSensor.swift](https://github.com/samhenrigold/LidAngleSensor/blob/main/LidAngleSensor/LidAngleSensor.swift). Source consulted September 10, 2026. HID sensor identification and feature-report layout.
7. Apple. [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos). ScreenCaptureKit sample. Complete-frame validation and buffer transport.
8. Apple. [Meet ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2022/10156/). WWDC22. Display/app/window filtering and avoiding recursive capture.

The video table provides the primary audiovisual references and time-indexed links. Observations, inference, and proposed implementation choices are separated throughout this report.
