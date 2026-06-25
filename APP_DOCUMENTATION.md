# MediQue App Documentation

## 1) Product Overview
MediQue is a Firebase-based clinic operating system with separate patient and doctor experiences, OTP-protected sign-in, smart queue orchestration, and operational analytics.

Core goals:
- Reduce waiting room chaos using live queue intelligence.
- Improve doctor throughput with a faster queue and patient workflow.
- Support SaaS onboarding/trial flows through a dedicated landing + sandbox.
- Enforce healthcare-grade security controls and auditable operations.

Primary app surfaces:
- `index.html`: Auth, role routing, OTP verification gate.
- `patient.html`: Patient app (join queue, ETA, appointments, history, chat, QR check-in).
- `doctor.html`: Doctor app (queue operations, notifications, bookings, finance, exports, chat, patient management).
- `saas.html`: SaaS landing page + trial lead capture.
- `trial_demo.html`: Interactive click-through demo for prospects.
- `functions/index.js`: Backend cloud functions (notifications, OTP, ML, security maintenance, role management).

---

## 2) High-Level Architecture
Frontend:
- Static HTML + JS app pages hosted on Firebase Hosting.
- Firebase Web SDK for Auth, Firestore, Functions, Messaging.

Backend:
- Firebase Cloud Functions (Node 20) for business logic, protected operations, scheduled jobs.
- Firestore for app data and audit/security stores.

Data zoning:
- Public app data: `artifacts/{appId}/public/data/...`
- User-scoped data: `artifacts/{appId}/users/...`
- Private security/compliance data: `artifacts/{appId}/private/...`

Security boundary:
- Firestore Rules (`firestore.rules`) enforce least privilege by role/ownership.
- Sensitive security datasets (OTP/audit archive) are admin-only.

---

## 3) Implemented Feature Inventory

### 3.1 Authentication & Access
- Email/password auth with role-based route split:
  - Admin email -> doctor app.
  - Other users -> patient app.
- OTP second factor flow:
  - `sendOtpEmail` callable sends a 6-digit OTP.
  - `verifyOtpAndLogin` callable verifies OTP and finalizes access.
- Custom forgot-password flow:
  - `sendPasswordResetLink` callable sends a reset link through configured SMTP sender.
- Role assignment support via `setUserRole` callable.

### 3.2 Patient Experience (`patient.html`)
- Join queue from home (`pre_registered`) or live waiting (`waiting`).
- Tokenized queue admission (4-digit token).
- Real-time queue status:
  - Position, ETA, confidence, load map, token card.
  - “Arrive just in time” guidance.
- Smart wait prediction via backend ML (`predictWaitTime` callable).
- QR check-in flow for clinic arrival.
- Appointment booking and appointment history.
- Patient history timeline and profile page.
- In-app chat/broadcast consumption.
- Push token registration for notifications (FCM path present).

### 3.3 Doctor Experience (`doctor.html`)
- Dashboard and queue monitor with live updates.
- Queue prioritization (including emergency-aware ordering metadata).
- Notify patient action via secure `notifyPatient` HTTP endpoint.
- Bookings/appointment workflows.
- Finance views:
  - Revenue, expenses, analytics tabs.
  - Reporting and export utilities.
- Telehealth/video flow components present.
- Broadcast messaging page.
- Patient management page.

### 3.4 SaaS/Go-To-Market Surfaces
- `saas.html`:
  - Product positioning + features + trial onboarding form.
  - Trial request capture to Firestore (`trial_signups`).
- `trial_demo.html`:
  - Product sandbox tabs for patient/doctor/owner-style storyline.

### 3.5 Backend Functions (`functions/index.js`)
Exports currently implemented:
- `phoneCallHook` (HTTP): telephony hook handling.
- `notifyPatient` (HTTP): admin-authenticated patient notification dispatch.
- `setUserRole` (callable): secure role assignment.
- `enrichQueueEntry` (Firestore trigger): enrich queue docs with context-at-join.
- `captureQueueTrainingSample` (Firestore trigger): capture model training samples from completed queue entries.
- `trainQueueModel` (callable): manual retraining (admin only).
- `scheduledQueueModelTraining` (scheduled): daily model retraining.
- `predictWaitTime` (callable): real-time ETA prediction API.
- `scheduledSecurityMaintenance` (scheduled): retention/redaction/archive tasks.
- `runSecurityMaintenanceNow` (callable): admin-triggered immediate maintenance.
- `sendOtpEmail` (callable): OTP issue.
- `sendPasswordResetLink` (callable): custom SMTP password reset email.
- `verifyOtpAndLogin` (callable): OTP verify.

---

## 4) Smart Queue ML Model (Current Implementation)

Model type:
- `ridge_regression_v2` (custom numeric pipeline in Cloud Functions).

Feature engineering:
- Queue-ahead volume, log/curve transforms.
- Urgent-ahead count and urgent ratio.
- Emergency flag.
- Time cyclicality (hour/day sine-cosine components).
- Peak-hour indicator.
- Avg consultation signal.

Training behavior:
- Uses recent training samples (90-day window, capped query volume).
- Robust normalization using median/IQR (`featureStats`).
- Ridge optimization with bounded residual influence.
- Validation metrics persisted (`mae`, `rmse`, `mape`).
- Residual percentiles stored (`residualP50`, `residualP90`).
- Near real-time adaptation:
  - New closed-visit samples trigger pending sample accumulation.
  - Automatic retrain occurs after configured sample delta + minimum time interval.
  - Lightweight lock avoids duplicate retrain races.

Prediction behavior:
- Blended estimate (model + conservative fallback).
- Confidence level: `high` / `medium` / `low` / `fallback`.
- Includes `predictionWindow.low/high` interval from residual band.

What “self-learning” means here:
- New closed-visit samples are captured automatically.
- Scheduled daily retraining updates model weights automatically.
- No manual retrain needed for routine adaptation.

---

## 5) Security Controls Implemented

### 5.1 Firestore Rules & Access Model
- Default deny model in `firestore.rules`.
- Admin role recognized by:
  - custom claim (`role == admin`), or
  - fallback admin email check.
- Owner-based permissions for patient-scoped records.
- Queue write restrictions for patient writes.
- Private namespace (`artifacts/{appId}/private/**`) admin-only.

### 5.2 OTP Hardening
- OTP hashed at rest (SHA-256 + pepper).
- Attempt limits and lockout/cooldown.
- OTP docs stored under private namespace.

### 5.3 API Hardening
- `notifyPatient` requires authenticated admin bearer token.
- Allowed-origin CORS list support for HTTP endpoints.

### 5.4 Auditability & Tamper Evidence
- Security actions logged in private audit collection.
- Incremental archive pipeline with hash chaining (`prevHash`, `payloadHash`).
- Archive metadata tracks sequence/chain continuity.

### 5.5 Retention & Data Minimization
- Scheduled maintenance handles:
  - queue redaction after retention threshold,
  - OTP deletion,
  - old ML sample deletion,
  - archived raw audit purging.

---

## 6) How To Perform Security Audit (Operational SOP)

### 6.1 Daily (Automated)
- `scheduledSecurityMaintenance` runs daily.
- `scheduledQueueModelTraining` runs daily.

Daily checks (Firebase Console):
1. Confirm scheduled runs completed without errors in Functions logs.
2. Verify audit docs exist in:
   - `artifacts/{appId}/private/audit_logs`
   - `artifacts/{appId}/private/audit_archive`
3. Verify model freshness in:
   - `artifacts/{appId}/public/data/ml_models/wait_time`
4. Verify no abnormal OTP failure spikes.

### 6.2 Weekly Security Review
1. Review Firestore Rules for drift from least-privilege intent.
2. Review admin accounts and role claims.
3. Verify retention results:
   - Old OTP docs removed.
   - Aged queue PHI redacted.
4. Inspect a sample of audit chain entries and confirm hash continuity (`prevHash` links).
5. Review notify endpoint usage patterns and origin/IP anomalies.

### 6.3 Monthly Compliance & Recovery Check
1. Secret rotation drill (SMTP, OTP pepper, webhook secret).
2. Restore drill (backup + test restore evidence).
3. Access review (remove stale team permissions).
4. Incident tabletop simulation.

### 6.4 Manual Security Maintenance Trigger
Callable available:
- `runSecurityMaintenanceNow` (admin only)

Recommended usage:
- Trigger after policy updates, migration events, or suspected stale retention execution.

---

## 7) Local Testing & Validation Guide

### 7.1 Local run
From project root:
```bash
firebase emulators:start
```

Or functions only:
```bash
cd functions
npm install
npm run serve
```

### 7.2 Core test scenarios
Auth/OTP:
- Login with valid credentials.
- OTP sent + verify success.
- OTP fail lockout/cooldown works.

Queue:
- Patient joins as `pre_registered` and `waiting`.
- Doctor can update queue states.
- Patient cannot modify unauthorized fields.

ML:
- Complete visits to generate training samples.
- Trigger manual retraining (`trainQueueModel`) using admin account.
- Confirm model doc updates and prediction confidence behavior.

Security:
- Verify non-admin denied on private namespace.
- Verify `notifyPatient` fails without admin bearer token.
- Verify audit docs are being written for sensitive actions.

---

## 8) Configuration Checklist Before Production

Update these values before go-live:
- `ADMIN_EMAIL` in:
  - `functions/index.js`
  - `firestore.rules`
  - frontend constants where applicable
- Environment variables (Functions):
  - `APP_ID`
  - `ADMIN_EMAIL`
  - `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
  - `OTP_PEPPER`, `OTP_MAX_ATTEMPTS`, `OTP_COOLDOWN_SECONDS`
  - `PHONE_HOOK_SECRET`
  - `ALLOWED_ORIGINS`
  - retention days variables
- Firestore indexes deployed (`firestore.indexes.json`).
- Firestore rules deployed (`firestore.rules`).

---

## 9) Compliance Positioning (Important)
Current system is security-hardened and compliance-oriented, but formal HIPAA compliance requires organizational controls outside code.

Still needed for full compliance program:
- Signed BAAs with all PHI processors/vendors.
- Formal access governance process.
- Incident response and breach notification workflow.
- Staff training and policy evidence.
- Periodic risk assessments and documented controls.

---

## 10) High-Impact Features To Add Next

### Priority 1 (Commercial impact)
- Multi-tenant SaaS admin service (separate secure backend, not client-only).
- Branch-level analytics rollup (clinic + branch + doctor dimensions).
- Automated no-show prediction and intervention workflows.
- WhatsApp delivery receipts + fallback channels (SMS/push).

### Priority 2 (Clinical operations)
- Voice-to-text doctor notes with structured SOAP templates.
- Smart follow-up scheduling engine by diagnosis/protocol.
- E-prescription signing + pharmacy integration workflows.
- Lab-order and result ingestion timeline in patient record.

### Priority 3 (Security/compliance maturity)
- KMS-managed key architecture and envelope encryption for sensitive fields.
- Immutable external audit export (WORM/SIEM integration).
- Break-glass access flow with mandatory reason + alerting.
- Device posture and session risk scoring.

### Priority 4 (ML maturity)
- Drift detection service with auto-alert when MAE crosses threshold.
- Model monitoring dashboard (cohort-level errors by hour/clinic).
- Feature store for versioned transformations and reproducibility.
- Online recalibration layer for sudden demand regime shifts.

---

## 11) Recommended Documentation Set (Next)
To scale delivery and onboarding, keep these docs in repo:
- `APP_DOCUMENTATION.md` (this file): full product + ops overview.
- `SECURITY_HARDENING.md`: tactical security runbook.
- `FIRESTORE_SETUP.md`: rules/index setup guide.
- `RUNBOOK_INCIDENT_RESPONSE.md`: security incident SOP.
- `RUNBOOK_RELEASE.md`: release + rollback checklist.
- `DATA_RETENTION_POLICY.md`: retention matrix by data class.

---

## 12) Quick Reference Paths
- Firestore rules: `firestore.rules`
- Functions backend: `functions/index.js`
- Patient app: `patient.html`
- Doctor app: `doctor.html`
- Auth gateway: `index.html`
- SaaS landing: `saas.html`
- Trial sandbox: `trial_demo.html`

