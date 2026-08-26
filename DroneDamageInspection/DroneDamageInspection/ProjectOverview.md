//
//  Damage.swift
//  DroneDamageInspection
//
//  Created by Amanda on 21/08/26.
//


# Drone Damage Inspection

## 1. Project Overview

This project aims to develop a **building visual inspection system** using the **DJI Tello EDU**, **Swift/SwiftUI**, **Computer Vision**, and **Core ML**.

The system captures building surfaces using the DJI Tello EDU camera, detects visible damage using a machine learning model, and visually marks the detected damage so inspectors can quickly identify areas that require further inspection.

### Project Scope

The system focuses on:

* Detecting visible surface damage.
* Identifying the approximate location of the damage within the camera frame.
* Marking detected damage using visual bounding boxes.
* Recording detected damage for inspection purposes.

### Out of Scope

The system does **not**:

* Determine whether a building is structurally safe.
* Predict building collapse.
* Calculate structural integrity.
* Determine the severity of structural failure.
* Provide engineering or safety certification.
* Automatically recommend repairs.

> **Core principle:** The system identifies and marks **visible damage**, not structural risk.

---

# 2. Main Objective

The target workflow is:

```text
DJI Tello EDU
      │
      │ Camera
      ▼
Live Video Stream
      │
      ▼
Swift Application
      │
      ▼
Computer Vision
      │
      ▼
Core ML Damage Detection
      │
      ▼
Damage Tracking
      │
      ▼
Damage Marker
      │
      ▼
Inspection Record
```

The final application should allow an inspector to:

1. Connect the DJI Tello EDU.
2. Control the drone.
3. View the live camera feed.
4. Start an inspection.
5. Detect visible damage.
6. Display markers around detected damage.
7. Track previously detected damage.
8. Save inspection results.

---

# 3. Technology Stack

| Component            | Technology              |
| -------------------- | ----------------------- |
| Drone                | DJI Tello EDU           |
| Programming Language | Swift                   |
| UI Framework         | SwiftUI                 |
| Networking           | Network.framework / UDP |
| Video Processing     | AVFoundation            |
| Video Decoding       | VideoToolbox            |
| Computer Vision      | Vision Framework        |
| Machine Learning     | Core ML                 |
| Object Detection     | YOLO → Core ML          |
| IDE                  | Xcode                   |

---

# 4. Reference Repositories

Three repositories will be used as technical references.

They are **not direct dependencies of the final Swift application**.

The final implementation will be written in Swift.

---

## 4.1 DJI Tello-Python

Repository:

https://github.com/dji-sdk/Tello-Python

### Purpose

Used primarily to understand the lower-level communication architecture of DJI Tello.

Important concepts to study:

```text
UDP Communication
      │
      ├── Command
      ├── Response
      ├── State
      └── Video
```

This repository will be particularly useful when implementing:

```text
UDPClient.swift
UDPListener.swift
VideoPacketReceiver.swift
VideoDecoder.swift
```

---

# 4.2 DJITelloPy

Repository:

https://github.com/damiafuentes/djitellopy

### Purpose

Used to understand a higher-level abstraction for Tello commands and drone control.

Examples of concepts to reference:

```text
Tello
│
├── connect()
├── takeoff()
├── land()
├── move_forward()
├── get_battery()
└── streamon()
```

These concepts will be translated into Swift:

```text
TelloService
│
├── connect()
├── takeOff()
├── land()
├── moveForward()
├── getBattery()
└── startVideoStream()
```

---

# 4.3 scratch3-tello

Repository:

https://github.com/kebhr/scratch3-tello

### Purpose

Used to understand how Tello functionality can be integrated into an interactive application through an abstraction layer.

The main concept we are interested in is:

```text
User Interface
      ↓
Command Abstraction
      ↓
Command Queue
      ↓
Tello Communication
```

This is relevant to our SwiftUI application because user actions will eventually follow:

```text
SwiftUI Button
      ↓
ViewModel
      ↓
TelloService
      ↓
TelloCommandQueue
      ↓
UDPClient
      ↓
DJI Tello EDU
```

---

# 5. Reference Mapping

| Reference        | Main Purpose                  | Swift Component                      |
| ---------------- | ----------------------------- | ------------------------------------ |
| DJI Tello-Python | Low-level Tello communication | `UDPClient`, `UDPListener`           |
| DJI Tello-Python | Video streaming concepts      | `VideoStreamService`, `VideoDecoder` |
| DJITelloPy       | Tello command abstraction     | `TelloService`                       |
| DJITelloPy       | Drone state handling          | `TelloStateService`                  |
| scratch3-tello   | Application integration       | `TelloService`, ViewModels           |
| scratch3-tello   | Command management            | `TelloCommandQueue`                  |

---

# 6. Project Architecture

The project will follow a layered architecture.

```text
                         SWIFTUI
                            │
             ┌──────────────┴──────────────┐
             │                             │
             ▼                             ▼
      DroneViewModel              InspectionViewModel
             │                             │
             ▼                             ▼
       TelloService              DetectionService
             │                             ▲
             ▼                             │
     TelloCommandQueue              Video Frames
             │                             │
             ▼                             │
         UDPClient               VideoStreamService
             │                             │
             └──────────────┬──────────────┘
                            │
                            ▼
                     DJI TELLO EDU
```

The inspection pipeline:

```text
DJI Tello EDU
      │
      ▼
VideoStreamService
      │
      ▼
VideoDecoder
      │
      ▼
Video Frame
      │
      ▼
Vision + Core ML
      │
      ▼
DamageDetectionService
      │
      ▼
DamageTrackingService
      │
      ▼
DamageMarker
      │
      ▼
InspectionRecord
```

---

# 7. Project Structure

```text
DroneDamageInspection/
│
├── App/
│   └── DroneDamageInspectionApp.swift
│
├── Core/
│   │
│   ├── Networking/
│   │   ├── UDPClient.swift
│   │   ├── UDPListener.swift
│   │   └── NetworkConfiguration.swift
│   │
│   └── Extensions/
│       └── ...
│
├── Drone/
│   ├── TelloService.swift
│   ├── TelloCommand.swift
│   ├── TelloCommandQueue.swift
│   ├── TelloResponse.swift
│   ├── TelloState.swift
│   ├── TelloStateService.swift
│   └── TelloStateParser.swift
│
├── Video/
│   ├── VideoStreamService.swift
│   ├── VideoPacketReceiver.swift
│   └── VideoDecoder.swift
│
├── Detection/
│   ├── DamageDetectionService.swift
│   ├── CoreMLModelService.swift
│   └── DamageTrackingService.swift
│
├── Models/
│   ├── Damage.swift
│   ├── DetectionResult.swift
│   └── InspectionRecord.swift
│
├── ViewModels/
│   ├── DroneViewModel.swift
│   └── InspectionViewModel.swift
│
├── Views/
│   │
│   ├── Drone/
│   │   ├── DroneControlView.swift
│   │   └── DroneStatusView.swift
│   │
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   └── LiveInspectionView.swift
│   │
│   ├── Detection/
│   │   └── DamageMarkerView.swift
│   │
│   └── Inspection/
│       ├── InspectionResultView.swift
│       └── DamageDetailView.swift
│
├── ML/
│   └── DamageDetector.mlmodel
│
├── Utilities/
│   ├── Constants.swift
│   └── Extensions.swift
│
├── Resources/
│   └── Assets.xcassets
│
└── README.md
```

---

# 8. Responsibilities of Each Layer

## Core

Responsible for low-level infrastructure.

```text
Core
│
├── UDPClient
├── UDPListener
└── NetworkConfiguration
```

This layer should not know about SwiftUI or damage detection.

---

## Drone

Responsible for DJI Tello functionality.

```text
Drone
│
├── TelloService
├── TelloCommand
├── TelloCommandQueue
├── TelloResponse
└── TelloState
```

This layer knows how to communicate with the Tello but does not manage the UI.

---

## Video

Responsible for receiving and decoding Tello's video stream.

```text
Video
│
├── VideoStreamService
├── VideoPacketReceiver
└── VideoDecoder
```

Output:

```text
Video Frame
```

---

## Detection

Responsible for computer vision.

```text
Detection
│
├── CoreMLModelService
├── DamageDetectionService
└── DamageTrackingService
```

Output:

```text
DetectionResult
```

---

## Models

Contains application data models.

Example:

```swift
struct Damage {
    let id: UUID
    let type: String
    let confidence: Float
    let boundingBox: CGRect
}
```

---

## ViewModels

Connect application logic to SwiftUI.

```text
View
  ↓
ViewModel
  ↓
Service
```

The ViewModel should coordinate services rather than directly communicating with UDP.

---

## Views

Contains the SwiftUI interface.

Examples:

```text
DroneControlView
DroneStatusView
CameraView
LiveInspectionView
DamageMarkerView
InspectionResultView
```

---

# 9. Tello Communication Architecture

The communication layer will follow:

```text
Swift Application
       │
       ▼
TelloService
       │
       ▼
TelloCommandQueue
       │
       ▼
UDPClient
       │
       ▼
Wi-Fi
       │
       ▼
DJI Tello EDU
```

The drone response follows the reverse direction:

```text
DJI Tello EDU
       │
       ▼
UDPListener
       │
       ▼
TelloResponse
       │
       ▼
TelloService
       │
       ▼
ViewModel
       │
       ▼
SwiftUI
```

---

# 10. TelloCommandQueue

The command queue is responsible for preventing multiple drone commands from being sent without proper response handling.

Instead of:

```text
takeoff
move forward
rotate
move up
land
```

being sent immediately, commands should be processed sequentially:

```text
Command #1
    │
    ▼
Send
    │
    ▼
Wait for Response
    │
    ▼
Command #2
    │
    ▼
Send
    │
    ▼
Wait for Response
    │
    ▼
Command #3
```

Example:

```text
Queue
│
├── command
├── battery?
└── streamon
```

Execution:

```text
command
   ↓
ok
   ↓
battery?
   ↓
85
   ↓
streamon
   ↓
ok
```

This approach will also make error handling and debugging easier.

---

# 11. Development Roadmap

The project will be implemented incrementally.

---

# Milestone 1 — Xcode Project Setup

## Status

Completed.

## Objective

Create the initial SwiftUI application and project architecture.

### Tasks

* [x] Create Xcode project.
* [x] Select Swift.
* [x] Select SwiftUI.
* [x] Create folder structure.
* [x] Create initial models.
* [x] Create service folders.
* [x] Create basic SwiftUI interface.
* [x] Add project constants.

### Success Criteria

The application builds and runs successfully with the intended architecture.

**Result:** Success. The project builds successfully with the initial architecture in place.

---

# Milestone 2 — UDP Communication

## Status

Completed. UDP communication has been validated with the physical Tello connection.

## Objective

Establish basic UDP communication with the DJI Tello EDU.

### Tasks

* [x] Connect Mac to Tello Wi-Fi.
* [x] Implement `UDPClient`.
* [x] Implement UDP endpoint configuration.
* [x] Send the `command` instruction.
* [x] Receive Tello response.
* [x] Handle connection errors.

### Expected Flow

```text
Swift
  │
  │ "command"
  ▼
Tello
  │
  │ "ok"
  ▼
Swift
```

### Success Criteria

The Swift application successfully receives `ok` from the Tello.

**Result:** Success. The app connects to the Tello and can execute takeoff and landing commands.

---

# Milestone 3 — TelloService

## Status

Completed. High-level Tello command API is implemented and connected to the SwiftUI flow.

## Objective

Create a clean high-level API for Tello.

### Initial API

```swift
connect()
disconnect()

sendCommand()

takeOff()
land()

getBattery()

startVideoStream()
stopVideoStream()
```

### Tasks

* [x] Create `TelloService`.
* [x] Create `TelloCommand`.
* [x] Connect `TelloService` to `UDPClient`.
* [x] Implement basic commands.
* [x] Connect command queue.

### Success Criteria

Basic drone commands can be executed through Swift.

**Result:** Success. `DroneViewModel` now calls `TelloService`, and `TelloService` exposes connect, disconnect, takeoff, land, battery, and video stream commands.

---

# Milestone 4 — Command Queue

## Status

Completed. Commands are executed sequentially through `TelloCommandQueue`.

## Objective

Implement sequential command execution.

### Tasks

* [x] Create `TelloCommandQueue`.
* [x] Add commands to queue.
* [x] Process one command at a time.
* [x] Wait for response.
* [x] Handle timeout.
* [x] Handle failed commands.
* [x] Resume queue after successful execution.

### Success Criteria

Commands execute sequentially and reliably.

**Result:** Success. `TelloCommandQueue` chains command tasks so each command waits for the previous command to finish before sending the next UDP command.

---

# Milestone 5 — Drone State

## Status

Completed in code. Live state updates are wired to UDP port 8890 and displayed in SwiftUI.

## Objective

Receive and parse Tello state information.

### State Examples

```text
Battery
Height
Speed
Temperature
Flight Time
```

### Tasks

* [x] Create `TelloStateService`.
* [x] Create `TelloStateParser`.
* [x] Parse state packets.
* [x] Create `TelloState`.
* [x] Display state in SwiftUI.

### Success Criteria

The application displays live drone information.

**Result:** Success. The app listens for state packets on UDP port 8890, parses battery, height, speed, temperature, and flight time, then displays them in `DroneStatusView`.

---

# Milestone 6 — Video Streaming

## Status

In progress. The app can send `streamon`, receive UDP video packets on port 11111, reconstruct Annex-B H.264 NAL units, decode frames with VideoToolbox, and display the latest decoded camera frame in SwiftUI. Hardware stream validation is still required.

## Objective

Receive the live camera feed from DJI Tello EDU.

### Workflow

```text
Tello
  │
  │ streamon
  ▼
UDP Video Packets
  │
  ▼
VideoPacketReceiver
  │
  ▼
H.264 Stream
  │
  ▼
VideoDecoder
  │
  ▼
Video Frame
  │
  ▼
SwiftUI
```

### Tasks

* [x] Send `streamon`.
* [x] Receive UDP video packets.
* [x] Reconstruct video stream.
* [x] Decode H.264.
* [x] Produce usable video frames.
* [x] Display live camera frame when decoding succeeds.

### Success Criteria

Live Tello video is visible in the Swift application.

**Current Result:** Packet receive, H.264 stream reconstruction, VideoToolbox decoding, and SwiftUI frame display are implemented. `CameraView` displays the latest decoded camera frame when available, plus packet count, byte count, NAL unit count, SPS/PPS count, detected frame NAL count, and decoded frame count for debugging.

---

# Milestone 7 — Image Capture

## Objective

Capture frames from the Tello camera.

### Tasks

* [x] Add capture button.
* [x] Capture current video frame.
* [x] Convert frame into image.
* [x] Save inspection image.
* [x] Associate image with inspection session.

### Success Criteria

The application can save images captured from the Tello camera.

**Current Result:** Success. `Capture Frame` saves the latest decoded Tello camera frame as a PNG in `DroneDamageInspectionCaptures` under the app documents directory, stores an `InspectionRecord`, and shows the captured frame in the inspection results list. The app can also record incoming Tello video packets as raw `.h264` files in `DroneDamageInspectionRecordings`, while throttling SwiftUI frame updates to reduce streaming lag.

---

# Milestone 8 — Dataset Preparation

## Objective

Prepare a dataset for visible damage detection.

### Initial Damage Categories

The MVP should start with a limited number of categories:

```text
0 - Crack
1 - Surface Damage
2 - Corrosion
```

### Dataset Workflow

```text
Images
  │
  ▼
Annotation
  │
  ▼
Train / Validation / Test
  │
  ▼
YOLO Dataset
```

### Tasks

* [ ] Collect existing damage images.
* [ ] Capture additional images using DJI Tello EDU.
* [ ] Annotate damage areas.
* [ ] Review annotation quality.
* [ ] Split dataset.
* [ ] Prepare YOLO-compatible dataset.

---

# Milestone 9 — Train Damage Detection Model

## Objective

Train an object detection model capable of identifying visible damage.

### Workflow

```text
Dataset
   │
   ▼
YOLO Training
   │
   ▼
Trained Model
   │
   ▼
Evaluation
   │
   ▼
Core ML Conversion
```

### Tasks

* [ ] Train YOLO model.
* [ ] Evaluate precision.
* [ ] Evaluate recall.
* [ ] Evaluate mAP.
* [ ] Test on DJI Tello images.
* [ ] Convert model to Core ML.
* [ ] Add `.mlmodel` to Xcode.

### Expected Model

```text
ML/
└── DamageDetector.mlmodel
```

---

# Milestone 10 — Core ML Integration

## Objective

Run damage detection directly from the Swift application.

### Workflow

```text
Video Frame
     │
     ▼
Vision Framework
     │
     ▼
DamageDetector.mlmodel
     │
     ▼
Detection Result
```

### Detection Output

```text
Damage #01
Type: Crack
Confidence: 91%
Bounding Box: CGRect
```

### Tasks

* [ ] Load Core ML model.
* [ ] Create Vision model.
* [ ] Create `VNCoreMLRequest`.
* [ ] Process video frames.
* [ ] Parse detection results.
* [ ] Convert results into application models.

---

# Milestone 11 — Damage Marker

## Objective

Visually mark detected damage in the live camera feed.

### Workflow

```text
Detection Result
      │
      ▼
Bounding Box
      │
      ▼
DamageMarkerView
      │
      ▼
SwiftUI Overlay
```

### Example

```text
┌──────────────────────────────────┐
│                                  │
│        BUILDING SURFACE          │
│                                  │
│        ┌───────────────┐         │
│        │ CRACK         │         │
│        │ Damage #01    │         │
│        │ 91%           │         │
│        └───────────────┘         │
│                                  │
└──────────────────────────────────┘
```

### Tasks

* [ ] Create `DamageMarkerView`.
* [ ] Draw bounding box.
* [ ] Display damage type.
* [ ] Display confidence.
* [ ] Assign damage ID.

---

# Milestone 12 — Damage Tracking

## Objective

Prevent the same physical damage from being recorded repeatedly.

Without tracking:

```text
Frame 1 → Damage #01
Frame 2 → Damage #02
Frame 3 → Damage #03
```

With tracking:

```text
Frame 1 → Damage #01
Frame 2 → Update Damage #01
Frame 3 → Update Damage #01
```

### Workflow

```text
New Detection
      │
      ▼
Compare Existing Damage
      │
      ▼
Same Damage?
   ┌──┴──┐
  YES    NO
   │      │
   ▼      ▼
Update   Create
Marker   Marker
```

### Initial Method

Use:

* Bounding box proximity.
* Intersection over Union (IoU).
* Detection consistency.

### Tasks

* [ ] Compare bounding boxes.
* [ ] Calculate IoU.
* [ ] Define threshold.
* [ ] Update existing markers.
* [ ] Create new markers.

---

# Milestone 13 — Inspection Records

## Objective

Store detected damage as an inspection record.

### Data Structure

```text
InspectionRecord
│
├── ID
├── Timestamp
├── Damage Type
├── Confidence
├── Image
└── Bounding Box
```

### Workflow

```text
Damage Detected
      │
      ▼
Capture Frame
      │
      ▼
Create InspectionRecord
      │
      ▼
Save
```

### Tasks

* [ ] Create `InspectionRecord`.
* [ ] Save detected damage.
* [ ] Save captured image.
* [ ] Save bounding box.
* [ ] Save timestamp.
* [ ] Display inspection history.

---

# Milestone 14 — Inspection Result Interface

## Objective

Create a final interface where users can review detected damage.

Example:

```text
INSPECTION RESULTS

┌─────────────────────────────┐
│ Damage #01                  │
│ Crack                       │
│ Confidence: 91%             │
│                             │
│ [ View Image ]              │
└─────────────────────────────┘

┌─────────────────────────────┐
│ Damage #02                  │
│ Surface Damage              │
│ Confidence: 86%             │
│                             │
│ [ View Image ]              │
└─────────────────────────────┘
```

### Tasks

* [ ] Create inspection results screen.
* [ ] Display damage list.
* [ ] Display damage details.
* [ ] Display captured image.
* [ ] Display confidence.
* [ ] Display timestamp.

---

# 12. Final System Workflow

The complete application should work as follows:

```text
                  USER
                   │
                   ▼
          SwiftUI Application
                   │
          ┌────────┴────────┐
          │                 │
          ▼                 ▼
     Drone Control      Inspection
          │                 │
          ▼                 ▼
    TelloViewModel    InspectionViewModel
          │                 │
          ▼                 ▼
     TelloService     DetectionService
          │                 ▲
          ▼                 │
   Command Queue        Video Frames
          │                 │
          ▼                 │
      UDP Client      VideoStreamService
          │                 │
          └────────┬────────┘
                   │
                   ▼
             DJI TELLO EDU
                   │
                   ▼
              Camera Feed
                   │
                   ▼
             Video Decoder
                   │
                   ▼
              Vision + Core ML
                   │
                   ▼
           Damage Detection
                   │
                   ▼
            Damage Tracking
                   │
                   ▼
             Damage Marker
                   │
                   ▼
          Inspection Record
                   │
                   ▼
          Inspection Results
```

---

# 13. MVP Definition

The MVP is complete when the system can successfully perform the following:

### Drone

* [ ] Connect to DJI Tello EDU.
* [ ] Send basic commands.
* [ ] Receive responses.
* [ ] Retrieve battery information.
* [ ] Receive drone state.

### Video

* [ ] Enable video streaming.
* [ ] Receive video packets.
* [ ] Decode video.
* [ ] Display live camera.
* [ ] Capture inspection frames.

### AI

* [ ] Load Core ML model.
* [ ] Detect visible damage.
* [ ] Identify damage type.
* [ ] Generate confidence score.
* [ ] Generate bounding box.

### Marker

* [ ] Display bounding box.
* [ ] Display damage type.
* [ ] Display confidence.
* [ ] Assign damage ID.
* [ ] Track repeated detections.

### Inspection

* [ ] Save detected damage.
* [ ] Save inspection image.
* [ ] Save timestamp.
* [ ] Display inspection results.

---

# 14. Development Order

The implementation should follow this order:

```text
PHASE 1
Project Setup
     ↓
PHASE 2
UDP Communication
     ↓
PHASE 3
TelloService
     ↓
PHASE 4
Command Queue
     ↓
PHASE 5
Drone State
     ↓
PHASE 6
Video Streaming
     ↓
PHASE 7
Image Capture
     ↓
PHASE 8
Dataset Preparation
     ↓
PHASE 9
YOLO Training
     ↓
PHASE 10
Core ML Integration
     ↓
PHASE 11
Damage Marker
     ↓
PHASE 12
Damage Tracking
     ↓
PHASE 13
Inspection Records
     ↓
PHASE 14
Final UI
```

---

# 15. Important Development Principle

Do **not** build the entire system at once.

Each milestone should produce a working prototype.

### Stage 1

```text
Swift → Tello
```

### Stage 2

```text
Swift → Tello
      ↓
   Camera
```

### Stage 3

```text
Camera
   ↓
Swift
   ↓
Core ML
```

### Stage 4

```text
Camera
   ↓
Core ML
   ↓
Damage Marker
```

### Stage 5

```text
Drone
   ↓
Camera
   ↓
AI
   ↓
Marker
   ↓
Inspection Record
```

This incremental approach makes it easier to identify whether problems come from **drone communication, video decoding, machine learning, or the UI**.

---

# 16. Final Project Goal

The final prototype aims to demonstrate:

```text
        DJI TELLO EDU
              │
              ▼
       BUILDING SURFACE
              │
              ▼
        CAMERA CAPTURE
              │
              ▼
       COMPUTER VISION
              │
              ▼
      VISIBLE DAMAGE
          DETECTED
              │
              ▼
        DAMAGE MARKER
              │
              ▼
      INSPECTION RESULT
```

The intended benefit is to help inspectors or workers **quickly locate visible damage identified by the system**, rather than manually searching the entire inspected surface.

> **The system is an inspection assistance tool, not a structural safety assessment system.**
