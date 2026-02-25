# Super Camera Library Architecture Design

- Date: 2026-02-25
- Project: DCamera (Android + iOS native camera library)
- Scope: V1 MVP architecture
- Status: Approved

## 1. Goals and Constraints

### Goals (V1 MVP)

- Camera frame capture and preview
- Photo capture
- Video recording
- Analysis mode preview pipeline foundation (for future QR/AI continuous analysis)
- Basic reusable camera UI (not full page app)

### Confirmed constraints

- Native-first public APIs:
  - Android Kotlin API
  - iOS Swift API
- Platform camera stack:
  - Android: pure Camera2 (AndroidX support utilities allowed when needed)
  - iOS: AVCaptureSession family
- Min OS:
  - Android 7.0+
  - iOS 13+
- Rendering engine:
  - bgfx is mandatory for all preview modes in V1:
    - pure preview
    - analysis preview
    - recording preview
- Recording path:
  - encoded input comes from bgfx offscreen render output (WYSIWYG target)

## 2. Architecture Option Decision

### Options evaluated

1. Native-first + shared C++ render core
2. Shared C++ media core + thin native adapters
3. Dual-native pipelines + shared contract only

### Selected option

Option 1: Native-first + shared C++ render core.

Reason:

- Fastest safe path for MVP
- Keeps platform-specific camera and media behavior stable
- Still creates a strong shared render core for future filter/watermark unification

## 3. System Architecture

## 3.1 Layered modules

1. Platform Capture Layer
- Android Camera2 session/device/request control
- iOS AVCaptureSession/device/input-output control

2. Shared Render Core (C++/bgfx)
- Upload camera frames into GPU textures
- Apply transform (rotation/mirror/crop)
- Render to preview surfaces
- Render offscreen frames for recorder input

3. Media Action Layer (platform native)
- Photo capture:
  - Android ImageReader/JPEG
  - iOS AVCapturePhotoOutput
- Video encode/mux:
  - Android MediaCodec + MediaMuxer
  - iOS AVAssetWriter

4. SDK Facade Layer
- Kotlin and Swift facades with aligned semantics
- Unified state and error contract

5. Basic UI Kit
- Preview container
- Photo/record controls
- State indicators (recording status, duration, permission hints)
- Replaceable by business-side custom UI

## 3.2 Core components

- CameraSessionController
  - startPreview(config)
  - stopPreview()
  - updateControl(controlPatch)

- PreviewRenderBridge
  - attachSurface(viewHandle)
  - detachSurface()
  - onFrameAvailable(frame, transform, ts)

- CaptureController
  - takePhoto(options)
  - cancelCapture()

- RecordController
  - startRecord(options)
  - stopRecord()
  - pauseRecord()/resumeRecord() (optional in V1)

- ResolutionSelector
  - select(mode, screenSpec, cameraCapabilities)
  - resolveFallback(requested)

- SdkFacade
  - aligned callbacks:
    - onStateChanged
    - onError(code, message, cause)
    - onPhotoSaved
    - onRecordSaved

## 3.3 State machine

IDLE -> INITIALIZING -> PREVIEWING -> CAPTURING or RECORDING -> PREVIEWING -> RELEASING -> IDLE

Any invalid transition returns INVALID_STATE.

## 4. Data Flow and Thread Model

## 4.1 Data flow

Preview flow (all modes)

- Camera frame output (YUV)
- PreviewRenderBridge wrapper (buffer + ts + transform)
- Shared Render Core (bgfx render)
- Display output to PreviewView

Photo flow

- CaptureController.takePhoto
- Native high quality photo output (V1 default JPEG)
- Save and callback with metadata

Video flow (WYSIWYG target)

- RecordController.startRecord
- bgfx offscreen render output as encode input
- Native encode/mux to MP4
- stopRecord returns file path and media metadata

## 4.2 Threading model

- Main/UI thread: UI interactions and API entry only
- Camera control thread: serialized device/session operations
- Frame IO thread: frame ingest and queue dispatch
- Render thread: bgfx submission and frame graph execution
- Encode thread: video/audio encode and mux

Principles:

- Control plane serialized, data plane parallel
- Bounded queue with backpressure
- Avoid unnecessary frame copies

## 5. Resolution Strategy

## 5.1 Work modes

- ANALYSIS
- PHOTO
- VIDEO

## 5.2 ANALYSIS mode (fullscreen reverse-fit)

Input:

- preview container size
- orientation
- supported camera sizes

Algorithm:

- Rank by aspect ratio delta to screen target (primary)
- Rank by area delta to screen target (secondary)
- Tie-break with lower compute load size

Goal:

- Keep analysis view aligned with screen geometry
- Reduce crop mismatch and coordinate mapping error

## 5.3 PHOTO/VIDEO mode

Default priority:

- 1920x1080 first
- fallback chain: 1600x900 -> 1280x720 -> 960x540

PHOTO and VIDEO may use separate selected outputs depending on device capability and stability.

## 5.4 Dynamic mode switch

- API: setWorkMode(mode)
- Reconfigure session outputs and render pipeline
- Target brief interruption (black frame interval controlled, target < 300ms)
- Emit onModeChanged with effective resolved resolution

## 6. Error Handling, Stability, Observability

## 6.1 Unified error domains

- PERMISSION
- DEVICE_UNAVAILABLE
- SESSION_CONFIG_FAILED
- RENDER_INIT_FAILED
- RENDER_SURFACE_LOST
- ENCODER_INIT_FAILED
- ENCODER_BACKPRESSURE
- FILE_IO_FAILED
- THERMAL_THROTTLE

## 6.2 Recovery strategy

- Recoverable:
  - surface lost
  - temporary backpressure
  - short camera interruption
  - auto rebuild render target/session

- Non-recoverable:
  - permission revoked
  - encoder init hard failure
  - stop affected flow and return explicit error

Optional runtime fallback flag:

- enableNativeEncodeFallback (default false)
- If bgfx-to-encoder pipeline is unavailable, switch to native direct encode with a clear non-WYSIWYG status flag

## 6.3 Stability controls

- Bounded frame queue depth
- Strict lifecycle order:
  - start: Session -> Render -> Encode
  - stop: reverse order
- Watchdog for no-frame timeout and self-healing actions

## 6.4 Observability

Metrics:

- first frame latency
- preview FPS
- render drop rate
- encoder input FPS
- A/V drift
- mode switch latency

Logging and diagnostics:

- structured logs keyed by sessionId
- one-shot diagnostic snapshot export for support/regression analysis

## 7. Testing Strategy

- Unit tests:
  - ResolutionSelector behavior by mode
  - state machine transitions
  - error mapping consistency

- Integration tests:
  - preview/photo/record core paths
  - mode switch stability
  - bgfx offscreen output to encoder path

- Device matrix:
  - Android across chipset vendors and camera combinations
  - iOS across at least two SoC generations and different aspect ratios

- Non-functional:
  - startup latency
  - FPS stability
  - thermal behavior
  - memory peak tracking

## 8. MVP Milestones

- M1: SDK skeleton and preview (bgfx) end-to-end
- M2: photo capability and metadata correctness
- M3: video recording via bgfx offscreen encode path
- M4: analysis mode resolution strategy + dynamic mode switching
- M5: stability hardening, observability completion, device regression pass

## 9. Future Extension Hooks (post-MVP)

RenderPass chain reserved inside Shared Render Core:

- BaseFramePass -> FilterPass -> WatermarkPass -> DisplayPass and EncodePass

This keeps preview and output frames aligned and supports future filter/watermark WYSIWYG behavior.

## 10. Acceptance Criteria for This Design

- Architecture matches all confirmed constraints and mode behavior
- Preview in all target modes uses bgfx
- Recording input is from bgfx offscreen output
- Resolution selection logic is mode-specific and deterministic
- Error and state semantics are aligned across Android and iOS public APIs
