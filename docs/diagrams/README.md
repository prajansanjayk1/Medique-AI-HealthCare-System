# MediQue — Screenshots & Diagrams

This directory contains visual assets for MediQue documentation.

## 📁 Directory Structure

```
docs/
├── architecture/
│   └── ARCHITECTURE.md          ← Technical architecture documentation
├── api/
│   └── API.md                   ← Full API reference
├── thought-process/
│   └── THOUGHT_PROCESS.md       ← Design rationale & decision log
├── diagrams/
│   └── README.md                ← This file
└── screenshots/
    └── README.md                ← Screenshot index
```

## 🗺️ Architecture Diagrams

| Diagram | Description |
|---|---|
| `system-architecture.png` | Full system architecture (16:9, 8K) |
| `socket-event-flow.png` | Socket.IO event flow diagram |
| `data-flow.png` | Client → Socket → Firestore write + broadcast loop |
| `security-zones.png` | Firestore security zone map |
| `ml-pipeline.png` | ML training and prediction pipeline |

> Place all diagram image files in this directory and reference them in README.md using relative paths.

## 📷 Screenshots

Place app screenshots in `docs/screenshots/` with the following naming convention:

| File | Description |
|---|---|
| `patient-queue-view.png` | Patient live queue with ETA and confidence |
| `patient-checkin-qr.png` | QR code check-in screen |
| `doctor-dashboard.png` | Doctor live queue management panel |
| `admin-analytics.png` | Admin analytics and audit dashboard |
| `flutter-home.png` | Flutter mobile app home screen |
| `payment-flow.png` | UPI QR payment workflow |
| `otp-screen.png` | OTP second factor authentication screen |

## 🎥 Demo

Add a demo video link or GIF in the README under a `## Demo` section.

Recommended: A 60–90 second screen recording showing:
1. Patient joining queue from mobile
2. Doctor panel updating in real-time
3. ETA updating live
4. "Your turn" notification arriving
5. Payment QR being generated and scanned
