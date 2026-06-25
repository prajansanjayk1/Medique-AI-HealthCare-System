# MediQue — Architecture Overview

> **Audience:** Engineers, architects, and technical reviewers.
> **Version:** 2.0 | **Last Updated:** June 2025

---

## 1. System Overview

MediQue is a **multi-tenant, event-driven clinic operating system** built on Firebase infrastructure. It serves four primary roles — **Patient**, **Doctor**, **Receptionist/POS**, and **Admin** — through separate optimized app surfaces, all synchronized in real-time via a central Socket.IO event hub.

---

## 2. Architecture Principles

| Principle | Implementation |
|---|---|
| **Event-Driven** | Socket.IO hub routes state changes to all connected clients |
| **Clients Never Write to DB Directly** | All mutations flow: Client → Hub → Node.js Core → Firestore |
| **Real-Time Broadcast Loop** | Firestore write confirmed → Node.js Core → Hub → `broadcast(queue_updated)` |
| **Default-Deny Security** | Firestore rules deny everything; grant only by role + ownership |
| **Self-Learning ML** | Ridge Regression auto-retrains on new visit samples |
| **Defense in Depth** | OTP hashing, CORS allowlist, audit chain, PHI redaction |

---

## 3. Layer Breakdown

### 3.1 Client Layer (Edge)

| Surface | Technology | Connection |
|---|---|---|
| Flutter Mobile App | Dart / Flutter 3.x | WSS → Socket.IO Hub |
| Patient Web App (`patient.html`) | HTML5 + Vanilla JS | WSS → Socket.IO Hub |
| Doctor Panel (`doctor.html`) | HTML5 + Vanilla JS | WSS → Socket.IO Hub |
| Admin Dashboard (`admin.html`) | HTML5 + Vanilla JS | WSS → Socket.IO Hub |
| POS / Reception Terminal | HTML5 + Vanilla JS | WSS → Socket.IO Hub |
| SMS Bot Interface | External SMS Gateway | HTTPS → Node.js REST API |

### 3.2 Socket.IO Event Hub

The event hub is the **central nervous system** of MediQue. All connected clients subscribe to a **clinic room** (`join_clinic_room({ clinicId })`), ensuring updates are scoped per clinic.

**Event Routing:**
- Incoming client events → Node.js handler → Firestore write → broadcast back to room
- ML triggers → `calculate_wait_time()` on queue mutation
- Notification triggers → `dispatch_sms_alert()` on ETA threshold breach

### 3.3 Backend Services

**Node.js Core (Firebase Cloud Functions):**
- Business logic for all mutations (queue, appointments, payments)
- OTP issuance, verification, and lockout management
- Patient notification dispatch (`notifyPatient` HTTP endpoint)
- Role management (`setUserRole`)

**ML Wait-Time Prediction:**
- Ridge Regression model (13 features, robust normalization)
- Near-real-time retraining after 15+ new samples
- Daily scheduled retraining for freshness
- Blended prediction: model + conservative fallback

**Smart Notification System:**
- FCM push (via `firebase-admin`)
- SMS via Twilio
- Email via Nodemailer (SMTP) for OTP and password reset

**Security & Audit:**
- SHA-256 + pepper OTP hashing
- Attempt limits (5) + cooldown (45s)
- Hash-chained audit archive
- Scheduled PHI redaction and data retention pipeline

### 3.4 Firestore Data Architecture

```
artifacts/{appId}/
├── public/data/
│   ├── queue/                    ← Live queue entries
│   ├── activeQueue/              ← Current active patient
│   ├── appointments/             ← Appointment records
│   ├── patients/                 ← Patient directory
│   ├── staff/                    ← Staff profiles & roles
│   ├── chatRooms/                ← E2EE chat rooms & messages
│   │   └── {roomId}/webrtc/      ← WebRTC signaling docs
│   ├── ml_models/wait_time       ← Active ML model weights
│   ├── ml_queue_samples/         ← Training dataset (rolling 90d)
│   ├── broadcast/                ← Clinic announcements
│   ├── public_keys/              ← E2EE public key registry
│   └── meta/tokenCounter         ← Token sequence counter
├── users/{userId}/
│   ├── profile/                  ← User profile
│   ├── registration/             ← Registration data
│   ├── visits/                   ← Visit history
│   ├── notifications/            ← Notification inbox
│   └── private/                  ← User-private data
└── private/security/
    ├── otps/                     ← Hashed OTPs (admin-only)
    ├── audit_logs/               ← Live audit events
    ├── audit_archive/            ← Hash-chained archive
    └── audit_archive_meta/state  ← Archive sequence state
```

---

## 4. Data Flow Diagrams

### 4.1 Patient Check-In Flow
```
Patient App
  │
  ├─ emit('patient_check_in', { patientId, clinicId })  [WSS]
  │
  ▼
Socket.IO Hub
  │
  ├─ routes to Node.js Core handler
  │
  ▼
Node.js Core
  ├─ Validates auth token
  ├─ Writes queue entry → Firestore
  ├─ Triggers: calculate_wait_time()
  │
  ▼
Firestore (queue write confirmed)
  │
  ▼
Node.js Core
  ├─ broadcast.to(clinicId).emit('queue_updated', { queueLength, positions })
  │
  ▼
Socket.IO Hub
  ├─ → Doctor Panel receives: queue_updated
  └─ → Patient App receives: eta_update { newEta, confidence }
```

### 4.2 SMS Bot Check-In Flow
```
Patient (SMS) → SMS Gateway
  │
  ├─ POST /phoneCallHook  [HTTPS REST]
  │
  ▼
Node.js API (verifies PHONE_HOOK_SECRET)
  ├─ Parses phone_number + clinicId
  ├─ Creates queue entry in Firestore
  ├─ emit('external_check_in', { phone_number, clinicId }) → Hub
  │
  ▼
Hub → broadcast('queue_updated') → Doctor Panel
```

### 4.3 ML Prediction Flow
```
New queue entry / queue mutation
  │
  ▼
Node.js Core triggers: calculate_wait_time()
  │
  ├─ Reads active ML model from Firestore (ml_models/wait_time)
  ├─ Builds 13-feature vector
  ├─ Normalizes with IQR-based robust scaler
  ├─ Computes dot(weights, features)
  ├─ Blends with conservative fallback
  ├─ Assigns confidence: high / medium / low / fallback
  │
  ▼
Returns: { eta, confidence, predictionWindow: { low, high } }
  │
  ▼
Hub emits: eta_update → Patient App
```

---

## 5. Security Zones

```
┌──────────────────────────────────────────────────────┐
│  PUBLIC ZONE                                         │
│  - Clinic status, clinic codes (unauthenticated read)│
│  - SaaS leads, trial signups (create only)           │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  AUTHENTICATED ZONE                                  │
│  - Queue read (all authenticated users)              │
│  - Appointments, staff profiles                      │
│  - Broadcast messages                                │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  ROLE-RESTRICTED ZONE                                │
│  - Queue mutations (patient = own entry only)        │
│  - Patient directory (doctor/admin/owner)            │
│  - Chat rooms (doctor + patient owner)               │
│  - Finance/expenses (admin only)                     │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  PRIVATE / ADMIN-ONLY ZONE                           │
│  - OTP documents                                     │
│  - Audit logs and archive                            │
│  - Security metadata                                 │
└──────────────────────────────────────────────────────┘
```

---

## 6. Technology Decision Log

| Decision | Choice | Rationale |
|---|---|---|
| Real-time transport | Socket.IO WSS | Native room scoping, fallback transports, wide ecosystem |
| Database | Cloud Firestore | Real-time listeners, offline support, serverless scaling |
| ML runtime | Cloud Functions (Node.js) | No separate infra; co-located with auth logic; fast cold starts |
| ML model | Ridge Regression | Interpretable, robust to outliers, trains in ms, no external deps |
| Notifications | FCM + Twilio + Nodemailer | Multi-channel redundancy for critical patient alerts |
| Auth | Firebase Auth + custom OTP | Leverages managed auth + adds healthcare-grade second factor |
| Mobile | Flutter | Single codebase for Android + iOS; rich animation support |
