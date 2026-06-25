# Changelog

All notable changes to MediQue will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Multi-tenant SaaS admin service with branch-level analytics
- WhatsApp notification delivery + fallback channel unification
- Automated no-show prediction workflow
- Voice-to-text doctor notes with SOAP template structuring
- E-prescription signing and pharmacy integration
- Drift detection dashboard for ML model monitoring
- KMS-managed envelope encryption for sensitive fields
- Break-glass admin access with mandatory audit alerting

---

## [2.0.0] — 2025-06

### Added
- **Flutter Mobile App v2.0** — Complete cross-platform app for patients, doctors, and receptionists
  - Patient: QR check-in, live queue position, ETA with confidence levels, appointment booking
  - Doctor: Live queue management, patient notifications, telehealth chat, finance views
  - Admin: Role management, security audit viewer, ML model retraining dashboard
- **Socket.IO Event Hub** — Bidirectional WSS real-time communication across all clients
  - `patient_check_in`, `join_clinic_room`, `queue_updated`, `eta_update`, `your_turn` events
  - POS Terminal integration via WSS
  - SMS Bot integration via HTTPS webhook → Hub relay
- **AI Wait-Time Prediction Engine** (`predictWaitTime` callable)
  - Ridge Regression v2 model with 13 engineered features
  - Confidence levels: `high`, `medium`, `low`, `fallback`
  - Near-real-time self-retraining after configurable sample delta
  - Daily scheduled retraining via `scheduledQueueModelTraining`
- **OTP Second Factor** — SHA-256 peppered, attempt-limited, cooldown-enforced
- **End-to-End Encrypted Chat** — WebRTC signaling in Firestore + public key registry
- **UPI Payment Workflow** — QR payment integration with patient-doctor billing
- **Audit Chain** — Hash-chained incremental audit archive with `prevHash` integrity
- **SaaS Landing Page** — Trial signup and lead capture (`saas.html`)
- **FCM Push Notifications** — Background service worker and foreground handler
- **Twilio SMS Integration** — Automated SMS alerts for queue turns and OTP delivery

### Changed
- Upgraded Cloud Functions runtime to **Node.js 20**
- Firestore security rules rewritten with **default-deny model**
- OTP storage moved to **private namespace** (admin-only access)
- CORS enforcement tightened to **origin allowlist** for all HTTP endpoints

### Security
- PHI redaction pipeline in `scheduledSecurityMaintenance`
- Audit logs now hash-redact email and IP fields before storage
- Queue write restrictions prevent unauthorized field mutation by patients

---

## [1.0.0] — 2025-01

### Added
- Initial Firebase-based clinic queue system
- Patient web app (`patient.html`) with basic queue join and status view
- Doctor web app (`doctor.html`) with queue list and basic patient controls
- Firebase Authentication with email/password
- Firestore real-time queue collection
- Basic role-based routing (admin email → doctor view)
- `notifyPatient` HTTP endpoint for doctor-triggered patient alerts
- `enrichQueueEntry` Firestore trigger for context enrichment on queue join
- `captureQueueTrainingSample` Firestore trigger for ML data collection
- Initial ML model training pipeline (`trainQueueModel` callable)
- Firestore security rules with basic role checks
- Admin dashboard initial version (`admin.html`)
- Firebase Hosting configuration with PWA manifest

---

[Unreleased]: https://github.com/yourusername/MediQue/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/yourusername/MediQue/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/yourusername/MediQue/releases/tag/v1.0.0
