<div align="center">

<img src="logo.png" alt="MediQue Logo" width="120" height="120" style="border-radius: 24px;" />

# 🏥 MediQue

### AI-Powered Real-Time Hospital Queue Management Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.x-010101?style=for-the-badge&logo=socket.io&logoColor=white)](https://socket.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen?style=for-the-badge)](CONTRIBUTING.md)

<br/>

> **MediQue** digitizes hospital queues using real-time event-driven architecture, AI-powered wait-time prediction, and multi-role dashboards — built for patients, doctors, receptionists, and administrators.

<br/>

[📱 Patient App](#-patient-experience) · [👨‍⚕️ Doctor Panel](#️-doctor-panel) · [🛡️ Admin Dashboard](#️-admin-dashboard) · [📡 Architecture](#-system-architecture) · [🚀 Setup](#-getting-started) · [📖 Docs](docs/)

<br/>

---

</div>

## 📋 Table of Contents

- [Problem Statement](#-problem-statement)
- [Proposed Solution](#-proposed-solution)
- [Key Features](#-key-features)
- [Technology Stack](#-technology-stack)
- [System Architecture](#-system-architecture)
- [Socket.IO Event Architecture](#-socketio-event-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Firebase Setup](#firebase-setup)
  - [Running the Flutter Client](#running-the-flutter-client)
  - [Running the Web Clients](#running-the-web-clients)
  - [Deploying Cloud Functions](#deploying-cloud-functions)
- [Environment Variables](#-environment-variables)
- [API Overview](#-api-overview)
- [App Surfaces](#-app-surfaces)
- [AI Wait-Time Prediction](#-ai-wait-time-prediction)
- [Security Architecture](#-security-architecture)
- [Future Enhancements](#-future-enhancements)
- [Team](#-team)
- [Acknowledgements](#-acknowledgements)
- [License](#-license)

---

## 🚨 Problem Statement

Hospitals worldwide lose thousands of productive hours daily to **disorganized patient queues**:

- 🕐 Patients wait **2–4 hours** with zero visibility into their queue position
- 📋 Doctors have no real-time dashboard to manage patient flow intelligently
- 📞 Receptionists manually track walk-ins using paper-based logs
- 🔔 No proactive notification system alerts patients when their turn approaches
- 💸 Payment workflows between patients and clinics are fragmented and manual

The result: **patient frustration**, **doctor burnout**, and **lost clinic revenue**.

---

## 💡 Proposed Solution

**MediQue** is a full-stack, event-driven clinic operating system that:

1. **Digitizes patient intake** via QR check-in, SMS bot, and POS terminals
2. **Predicts wait times** using a self-learning Ridge Regression ML model trained on historical queue data
3. **Synchronizes all stakeholders** in real-time using Socket.IO event broadcasting
4. **Delivers smart notifications** via FCM push, SMS (Twilio), and email
5. **Secures all operations** with OTP 2FA, role-based Firestore rules, and tamper-evident audit logs

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 🔴 **Live Queue Management** | Real-time patient queue with tokenized admission, position tracking, and priority ordering |
| ⚡ **Socket.IO Event Hub** | Bidirectional WSS communication between all app surfaces |
| 🤖 **AI Wait-Time Prediction** | Self-learning Ridge Regression model with confidence intervals (high/medium/low) |
| 🔔 **Smart Notifications** | FCM push + SMS (Twilio) + in-app alerts at configurable ETA thresholds |
| 👨‍⚕️ **Doctor Dashboard** | Live queue monitor, patient management, telehealth, finance exports |
| 🛡️ **Admin Panel** | Security audit, role management, ML model retraining, broadcast messaging |
| 🏪 **Reception/POS** | Physical kiosk and receptionist terminal for walk-in patient intake |
| 🔐 **Firebase Auth + OTP** | Email/password + SHA-256 peppered OTP second factor |
| 📊 **Live Queue Analytics** | Real-time load maps, ETA confidence, peak-hour indicators |
| 💳 **Payment Workflow** | UPI QR payment integration with patient-doctor billing flows |
| 💬 **In-App Chat** | End-to-end encrypted WebRTC-powered telehealth chat |
| 🌍 **SMS Bot Interface** | REST webhook allowing feature-phone patients to join queues via SMS |
| 📱 **Flutter Mobile App** | Cross-platform mobile client for patients, doctors, and receptionists |

---

## 🛠️ Technology Stack

### Frontend / Client
| Layer | Technology |
|---|---|
| Mobile App | Flutter 3.x (Dart) |
| Web Client | Vanilla HTML5 + JS (Firebase Hosting) |
| State Management | Provider |
| Animations | flutter_animate, Lottie, Shimmer |
| QR Integration | qr_flutter, mobile_scanner |
| PDF Generation | pdf, printing |
| Fonts | Google Fonts |

### Backend / Cloud
| Layer | Technology |
|---|---|
| Runtime | Node.js 20 (Firebase Cloud Functions) |
| Real-Time Hub | Socket.IO 4.x (WSS) |
| Database | Cloud Firestore |
| Auth | Firebase Authentication |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| SMS | Twilio |
| Email / OTP | Nodemailer (SMTP) |
| Storage | Firebase Storage |
| HTTP Client | Axios |

### ML & Analytics
| Component | Details |
|---|---|
| Model Type | Ridge Regression v2 (custom numeric pipeline) |
| Features | Queue depth, urgent ratio, time cyclicality, peak-hour, avg consultation |
| Training | Scheduled daily + near-real-time retraining on new samples |
| Validation | MAE, RMSE, MAPE persisted per model version |
| Confidence | `high` / `medium` / `low` / `fallback` with prediction intervals |

### Infrastructure
| Layer | Technology |
|---|---|
| Hosting | Firebase Hosting |
| Functions | Firebase Cloud Functions (Node 20) |
| Security | Firestore Rules, SHA-256 OTP, CORS allow-list, audit chain |
| CI/CD | GitHub Actions (optional) |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENT APPLICATIONS                             │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  ┌───────────┐ │
│  │  Flutter App │  │  Patient Web │  │  Doctor Panel │  │   Admin   │ │
│  │  (Mobile)    │  │  (patient.   │  │  (doctor.html)│  │ Dashboard │ │
│  │              │  │   html)      │  │               │  │(admin.html│ │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘  └─────┬─────┘ │
│         │ WSS              │ WSS               │ WSS            │ WSS   │
│  ┌──────┴───────┐          │                   │                │       │
│  │  POS Terminal│──────────┘                   │                │       │
│  └──────────────┘  emit('patient_check_in')    │                │       │
│  ┌──────────────┐                               │                │       │
│  │  SMS Bot     │──── HTTPS (REST) ─────────────┼────────────────┘       │
│  └──────────────┘                               │                        │
└─────────────────────────────────────────────────┼────────────────────────┘
                                                  │
                          ┌───────────────────────┼───────────────────────┐
                          │           SOCKET.IO EVENT HUB                 │
                          │                                               │
                          │  • emit('join_clinic_room', {clinicId})       │
                          │  • emit('patient_check_in', {patientId})      │
                          │  • broadcast('queue_updated', {queueLength})  │
                          │  • emit('eta_update', {newEta, position})     │
                          │  • emit('next_patient', {clinicId})           │
                          └───────────┬───────────────────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────────┐
              │                       │                           │
    ┌─────────▼────────┐   ┌──────────▼──────────┐   ┌───────────▼──────────┐
    │   Node.js Core   │   │  ML Wait-Time Pred. │   │  Smart Notifications │
    │   (Business      │   │  (Ridge Regression) │   │  (FCM + SMS + Email) │
    │    Logic)        │   │  trigger:           │   │  trigger:            │
    └─────────┬────────┘   │  calculate_wait     │   │  dispatch_sms_alert  │
              │            │  _time()            │   └──────────────────────┘
              │            └─────────────────────┘
              │
    ┌─────────▼────────────────────────────────────────────────────────────┐
    │                    CLOUD FIRESTORE (Firebase)                        │
    │                                                                      │
    │  artifacts/{appId}/                                                  │
    │  ├── public/data/queue/         ← Queue entries (live)               │
    │  ├── public/data/appointments/  ← Appointment records                │
    │  ├── public/data/ml_models/     ← Trained ML model weights           │
    │  ├── public/data/ml_queue_samples/ ← Training dataset               │
    │  ├── users/{userId}/            ← User profiles & visit history      │
    │  └── private/security/          ← OTP, audit logs, archive (Admin)   │
    └──────────────────────────────────────────────────────────────────────┘
```

> **Key Design Principle:** Clients **never** write directly to Firestore through sockets. All mutations flow through Node.js Core → Firestore. Confirmed writes trigger a Node.js Core → Socket Hub broadcast back to all connected clients.

---

## 📡 Socket.IO Event Architecture

### Connection Protocols

| Client | Protocol | Connection Target |
|---|---|---|
| Patient App (Flutter/Web) | **WSS** (WebSocket Secure) | Socket.IO Hub |
| Doctor Panel | **WSS** | Socket.IO Hub |
| Admin Dashboard | **WSS** | Socket.IO Hub |
| POS / Reception Terminal | **WSS** | Socket.IO Hub |
| SMS Bot | **HTTPS (REST)** | Node.js API webhook |

### Event Catalog

#### ⬆️ Upstream — Client → Hub
| Event | Payload | Emitter |
|---|---|---|
| `join_clinic_room` | `{ clinicId }` | All clients |
| `patient_check_in` | `{ patientId, clinicId, token }` | Patient App / POS |
| `leave_queue` | `{ patientId, clinicId }` | Patient App |
| `next_patient` | `{ clinicId, currentPatientId }` | Doctor Panel |
| `mark_emergency` | `{ patientId, clinicId }` | Doctor Panel |
| `request_payment` | `{ patientId, amount, method }` | Doctor Panel |
| `external_check_in` | `{ phone_number, clinicId }` | SMS Bot → API → Hub |

#### ⬇️ Downstream — Hub → Clients
| Event | Payload | Recipients |
|---|---|---|
| `queue_updated` | `{ queueLength, nextPatient, positions }` | Doctor Panel, Admin |
| `eta_update` | `{ newEta, positionInQueue, confidence }` | Patient App |
| `your_turn` | `{ patientId, token, doctorName }` | Patient App |
| `payment_requested` | `{ amount, upiId, qrData }` | Patient App |
| `broadcast_message` | `{ message, type, clinicId }` | All clients |
| `queue_cleared` | `{ clinicId, clearedBy }` | All clients |

#### 🔀 Backend Triggers (Hub → Services)
| Trigger | Service | Description |
|---|---|---|
| `calculate_wait_time()` | ML Prediction Engine | Computes ETA on queue mutation |
| `dispatch_sms_alert()` | Smart Notifications | SMS via Twilio on turn approach |
| `writeAuditLog()` | Security Audit Chain | Logs sensitive actions |

---

## 📁 Project Structure

```
MediQue/
├── mediqueue_flutter/          # 📱 Flutter Cross-Platform Mobile App
│   ├── lib/
│   │   ├── core/
│   │   │   ├── services/       # Firebase, Auth, Firestore services
│   │   │   ├── widgets/        # Shared UI components
│   │   │   ├── theme.dart      # Design system & color palette
│   │   │   └── utils.dart      # Utility functions
│   │   ├── features/
│   │   │   ├── auth/           # Login, OTP, role routing
│   │   │   ├── patient/        # Queue join, ETA, appointments
│   │   │   ├── doctor/         # Queue management, dashboard
│   │   │   └── admin/          # Admin controls, analytics
│   │   ├── firebase_options.dart
│   │   └── main.dart
│   └── pubspec.yaml
│
├── functions/                  # ☁️ Firebase Cloud Functions (Node.js 20)
│   ├── index.js                # All cloud function exports
│   ├── package.json
│   └── .env                    # Environment configuration
│
├── patient.html                # 🏥 Patient Web App
├── doctor.html                 # 👨‍⚕️ Doctor Panel
├── admin.html                  # 🛡️ Admin Dashboard
├── index.html                  # 🔐 Auth Gateway
├── saas.html                   # 🚀 SaaS Landing Page
│
├── firestore.rules             # 🔒 Firestore Security Rules
├── firestore.indexes.json      # 🗄️ Composite Index Definitions
├── firebase.json               # Firebase Project Configuration
├── firebase-messaging-sw.js    # FCM Service Worker
│
├── docs/                       # 📖 Documentation
│   ├── architecture/           # Architecture diagrams & decisions
│   ├── api/                    # API reference
│   ├── diagrams/               # System & event diagrams
│   ├── thought-process/        # Design rationale & hackathon sheet
│   └── screenshots/            # App screenshots
│
├── .github/
│   ├── ISSUE_TEMPLATE/         # Bug report & feature request templates
│   ├── workflows/              # CI/CD pipelines
│   └── pull_request_template.md
│
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── LICENSE
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:

```bash
# Flutter SDK (3.x+)
flutter --version

# Node.js (20.x+)
node --version

# Firebase CLI
npm install -g firebase-tools
firebase --version
```

### Firebase Setup

1. **Create a Firebase Project** at [console.firebase.google.com](https://console.firebase.google.com)

2. **Enable Services:**
   - Authentication (Email/Password)
   - Cloud Firestore
   - Cloud Functions
   - Firebase Hosting
   - Firebase Storage
   - Firebase Cloud Messaging (FCM)

3. **Deploy Security Rules:**
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

4. **Set Function Environment Variables:**
```bash
firebase functions:config:set \
  security.otp_pepper="your-secret-pepper" \
  security.otp_max_attempts="5" \
  security.otp_cooldown_seconds="45" \
  smtp.user="your-smtp-user" \
  smtp.pass="your-smtp-password"
```

For detailed Firebase setup, see [FIRESTORE_SETUP.md](FIRESTORE_SETUP.md).

### Running the Flutter Client

```bash
# Navigate to Flutter project
cd mediqueue_flutter

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ipa --release
```

### Running the Web Clients

```bash
# Start Firebase Emulators (includes Hosting + Functions)
firebase emulators:start

# App surfaces available at:
# http://localhost:5000/           → Auth Gateway
# http://localhost:5000/patient.html → Patient App
# http://localhost:5000/doctor.html  → Doctor Panel
# http://localhost:5000/admin.html   → Admin Dashboard
```

### Deploying Cloud Functions

```bash
cd functions
npm install

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:predictWaitTime
```

---

## 🔑 Environment Variables

Create a `functions/.env` file with the following:

```env
# Application
APP_ID=your-firebase-project-id
ADMIN_EMAIL=your-admin@example.com

# SMTP (OTP / Password Reset Emails)
SMTP_USER=your-smtp-username
SMTP_PASS=your-smtp-password
SMTP_FROM=noreply@yourapp.com

# Security
OTP_PEPPER=change-me-to-a-strong-random-secret
OTP_MAX_ATTEMPTS=5
OTP_COOLDOWN_SECONDS=45
PHONE_HOOK_SECRET=your-telephony-webhook-secret

# CORS
ALLOWED_ORIGINS=https://your-app.web.app,http://localhost:5000

# Data Retention (days)
RETENTION_QUEUE_DAYS=365
RETENTION_AUDIT_DAYS=2190
RETENTION_OTP_DAYS=30
RETENTION_ML_SAMPLE_DAYS=365

# ML Retraining
NEAR_RT_RETRAIN_MIN_INTERVAL_MINUTES=20
NEAR_RT_RETRAIN_SAMPLE_DELTA=15
```

> ⚠️ **Never commit `.env` or Firebase service account keys to version control.**

---

## 📡 API Overview

### HTTP Endpoints (Firebase Cloud Functions)

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/notifyPatient` | `POST` | Admin Bearer Token | Dispatches a notification to a specific patient |
| `/phoneCallHook` | `POST` | Hook Secret | Handles incoming telephony webhook events |

### Callable Functions

| Function | Role Required | Description |
|---|---|---|
| `sendOtpEmail` | Any authenticated user | Issues a 6-digit OTP to the user's email |
| `verifyOtpAndLogin` | Any authenticated user | Verifies OTP and finalizes session |
| `sendPasswordResetLink` | Unauthenticated | Sends custom SMTP password reset link |
| `setUserRole` | Admin | Assigns custom role claim to a user |
| `predictWaitTime` | Authenticated | Returns ML-based ETA with confidence level |
| `trainQueueModel` | Admin | Triggers immediate model retraining |
| `runSecurityMaintenanceNow` | Admin | Runs data retention and audit archiving immediately |

### Scheduled Jobs

| Job | Schedule | Description |
|---|---|---|
| `scheduledQueueModelTraining` | Daily | Retrains the ML wait-time model on fresh samples |
| `scheduledSecurityMaintenance` | Daily | PHI redaction, OTP purge, audit archiving |

---

## 📱 App Surfaces

### 🏥 Patient Experience
- Join queue from home (`pre_registered`) or in-clinic (`waiting`)
- 4-digit tokenized admission
- Live position, ETA, and confidence level display
- QR code check-in on clinic arrival
- Appointment booking & history timeline
- In-app chat with doctor
- Push notification when turn approaches
- UPI QR payment on doctor request

### 👨‍⚕️ Doctor Panel
- Live queue monitor with real-time updates
- Emergency patient override and priority ordering
- Patient notification via secure `notifyPatient` endpoint
- Appointment and booking management
- Finance and revenue analytics
- Broadcast messaging to all waiting patients
- In-app telehealth chat + WebRTC video

### 🛡️ Admin Dashboard
- Clinic-wide oversight and queue controls
- Security audit log viewer
- Role assignment and staff management
- ML model retraining dashboard
- Data retention management
- Broadcast and announcement system
- Financial reporting and expense tracking

### 🏪 Reception / POS Terminal
- Physical walk-in patient intake
- Connects to Socket.IO Hub via WSS
- Emits `patient_check_in` and `join_clinic_room` events directly

---

## 🤖 AI Wait-Time Prediction

MediQue features a **self-learning ML pipeline** built entirely within Firebase Cloud Functions.

### Model Architecture
```
Model Type    : Ridge Regression v2
Feature Count : 13 engineered features
Training Set  : 90-day rolling window of completed visits
Validation    : MAE, RMSE, MAPE persisted per version
```

### Feature Engineering
| Feature | Description |
|---|---|
| `queueAhead` | Number of patients ahead in queue |
| `log(queueAhead)` | Log-transform for non-linear scaling |
| `queueAhead²/100` | Quadratic queue pressure |
| `urgentAhead` | Count of urgent patients ahead |
| `urgentRatio` | Urgent fraction of total queue |
| `isEmergency` | Emergency flag (binary) |
| `sin/cos(hour)` | Time-of-day cyclicality |
| `sin/cos(dayOfWeek)` | Day-of-week cyclicality |
| `peakHour` | Binary: 9–13h or 17–20h |
| `avgConsultationMinutes` | Historical avg session length |

### Self-Learning Pipeline
1. Completed visits automatically capture training samples (Firestore trigger)
2. After every `N` new samples, a near-real-time retrain is triggered (with lock to prevent races)
3. Daily scheduled retraining ensures freshness even on low-traffic days
4. Confidence levels guide UI display: `high` → precise ETA, `fallback` → "~X mins"

---

## 🔒 Security Architecture

| Control | Implementation |
|---|---|
| **Firestore Rules** | Default-deny; role/owner-based least privilege |
| **OTP** | SHA-256 + pepper hashed at rest; attempt limits + cooldown |
| **Admin Auth** | Custom claim (`role == admin`) OR email allowlist |
| **API Security** | Bearer token verification on all HTTP endpoints |
| **CORS** | Origin allowlist enforced on HTTP functions |
| **Audit Logs** | Hash-chained incremental archive (`prevHash` linking) |
| **PHI Redaction** | Scheduled retention pipeline auto-redacts aged queue data |
| **E2EE Chat** | WebRTC + public key registry for end-to-end encrypted messages |

---

## 🔮 Future Enhancements

### Priority 1 — Commercial Impact
- [ ] Multi-tenant SaaS admin service with branch-level analytics
- [ ] Automated no-show prediction and intervention workflows
- [ ] WhatsApp delivery + fallback channel (SMS/push) unification

### Priority 2 — Clinical Operations
- [ ] Voice-to-text doctor notes with SOAP template structuring
- [ ] Smart follow-up scheduling engine by diagnosis protocol
- [ ] E-prescription signing + pharmacy integration
- [ ] Lab order and result ingestion in patient timeline

### Priority 3 — ML Maturity
- [ ] Drift detection with MAE threshold alerting
- [ ] Model monitoring dashboard (cohort-level errors by hour/clinic)
- [ ] Online recalibration layer for sudden demand shifts

### Priority 4 — Security / Compliance
- [ ] KMS-managed envelope encryption for sensitive fields
- [ ] Break-glass access with mandatory reason + audit alert
- [ ] SIEM/WORM immutable external audit export

---

## 👥 Team

| Role | Name |
|---|---|
| 🧑‍💻 Lead Developer & Architect | **Prajan Sanjay K** |
| 🎨 UI/UX Designer | Team Member |
| ☁️ Backend Engineer | Team Member |
| 📊 ML Engineer | Team Member |

> Built for **[Hackathon Name]** — National/State Level.

---

## 🙏 Acknowledgements

- [Firebase](https://firebase.google.com) — Backend infrastructure and real-time database
- [Flutter](https://flutter.dev) — Cross-platform mobile framework
- [Socket.IO](https://socket.io) — Real-time bidirectional event communication
- [Twilio](https://twilio.com) — SMS notification delivery
- [Nodemailer](https://nodemailer.com) — SMTP email for OTP and password reset
- [Google Fonts](https://fonts.google.com) — Beautiful open-source typography

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ for better healthcare experiences**

⭐ Star this repository if MediQue inspired you!

[🐛 Report Bug](../../issues) · [✨ Request Feature](../../issues) · [🤝 Contribute](CONTRIBUTING.md)

</div>
