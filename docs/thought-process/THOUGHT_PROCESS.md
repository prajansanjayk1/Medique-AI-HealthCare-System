# MediQue — Thought Process & Design Rationale

> **For:** Hackathon judges, technical reviewers, and portfolio visitors
> **Purpose:** Explain the "why" behind every major architectural and product decision

---

## 1. Problem Identification

We observed a recurring pain point in Indian outpatient clinics: patients arrive at a hospital with no idea how long they will wait. The result is crowded waiting rooms, anxious patients, and doctors who have no structured way to manage their queue. Receptionists use paper registers or basic Excel sheets.

**Core problems we identified:**
1. **Patients** have zero visibility into wait times → anxiety, no-shows, poor experience
2. **Doctors** lack a real-time dashboard → missed emergencies, inefficient throughput
3. **Clinics** lose revenue due to disorganized patient flow and missed appointments
4. **Feature-phone patients** (a large demographic in India) have no digital access to queues

---

## 2. Why Socket.IO?

We evaluated three real-time solutions:

| Option | Pros | Cons |
|---|---|---|
| **Firebase Realtime DB listeners** | Simple, no extra infra | Polling overhead, no room-based scoping |
| **Firebase Firestore onSnapshot** | Offline support | Not a push model; document-level only |
| **Socket.IO (WSS)** | True push, room scoping, bidirectional, fallbacks | Requires server |

**Decision:** Socket.IO was chosen because it allows fine-grained event vocabulary (e.g., `your_turn`, `queue_updated`, `mark_emergency`) that maps directly to clinical workflows. Room-based broadcasting ensures clinic isolation without client-side filtering.

---

## 3. Why Ridge Regression for ML?

We explored three approaches for wait-time prediction:

| Approach | Pros | Cons |
|---|---|---|
| **Neural Network** | High accuracy | Requires TensorFlow.js or external serving; heavy cold starts in Cloud Functions |
| **Random Forest** | Good accuracy | No zero-dep Node.js implementation; serialization complexity |
| **Ridge Regression** | Interpretable, trains in milliseconds, zero external deps | Lower ceiling accuracy |

**Decision:** Ridge Regression fits perfectly inside Firebase Cloud Functions with no extra infrastructure. It can retrain on every 15 new samples in under 500ms. The 13 engineered features (including time cyclicality via sine/cosine encoding) provide strong predictive power for clinical queue patterns.

The **self-learning pipeline** is the key differentiator: new completed visits automatically create training samples, and the model retrains itself — no human intervention needed after deployment.

---

## 4. Why Multi-Surface Architecture?

Rather than a single monolithic app, we designed role-specific surfaces:

| Surface | Reason |
|---|---|
| `patient.html` | Lightweight, PWA-installable, works on low-end devices |
| `doctor.html` | Feature-rich dashboard for high-frequency professional use |
| `admin.html` | Full control plane, not exposed to patient audience |
| Flutter mobile | Native-feel notifications, geofencing, QR scanner, biometric auth |
| SMS Bot | Inclusive for feature-phone patients; India-specific need |
| POS Terminal | Covers walk-in patients at the physical reception desk |

This architecture ensures that each user group gets an **optimized experience** without compromising security or performance for the others.

---

## 5. Why Firebase Cloud Functions for ML?

We deliberately chose **not** to deploy a separate ML server because:

- No additional server management or cold-start infra for a hackathon/MVP
- Functions can access Firestore directly (model weights stored as a Firestore doc)
- Near-real-time retraining (15 sample delta) is achievable within function execution limits
- Scales automatically with Firebase

The trade-off is a ceiling on model complexity — but Ridge Regression with good feature engineering achieves sub-5-minute MAE in clinical settings, which is clinically meaningful.

---

## 6. Security Design Philosophy

Healthcare data is PHI (Protected Health Information). We designed every layer with this in mind:

- **Default-deny Firestore rules** — nothing is readable unless explicitly granted
- **Private namespace** — OTPs, audit logs, and security data are invisible to frontend clients
- **OTP hashing** — even if the Firestore database were compromised, OTPs are unrecoverable without the pepper
- **Audit chain** — hash-chained archive creates tamper-evident history of all sensitive operations
- **PHI redaction pipeline** — automated scheduled job ensures patient data is purged after retention window

---

## 7. Inclusive Design: The SMS Bot

India has ~700 million feature-phone users. A hospital app targeting rural India **must** offer SMS-based access. The SMS Bot flow:

1. Patient texts a clinic shortcode: "JOIN QUEUE"
2. SMS gateway forwards to `/phoneCallHook` (HTTPS)
3. Node.js verifies the hook secret, creates a queue entry, emits `external_check_in` to the Socket Hub
4. Doctor panel receives `queue_updated` with the SMS patient included
5. Patient receives SMS back with their token number and estimated wait

This same flow can be extended to WhatsApp Business API with minimal changes.

---

## 8. Payment Workflow Design

We chose **UPI QR** as the primary payment method because:
- 85%+ of Indian smartphone users have a UPI app (GPay, PhonePe, Paytm)
- No payment gateway integration fees for the clinic
- Doctor can request payment via the dashboard; patient receives a QR in-app
- Transaction ID is captured and stored in the queue entry for reconciliation

---

## 9. What We Would Do Differently With More Time

1. **WebSocket server decoupled from Firebase Functions** — Socket.IO would ideally run on a persistent Node.js server (e.g., Cloud Run) rather than Firebase Functions, which have connection limits
2. **Dedicated ML microservice** — A FastAPI + scikit-learn service for more powerful models (XGBoost, LightGBM) as data grows
3. **WhatsApp Business API** integration for the SMS Bot channel
4. **HIPAA BAA** with all PHI processors for formal compliance
5. **Kubernetes deployment** with horizontal scaling for multi-hospital rollout

---

## 10. Hackathon Differentiators

| Feature | Why It Stands Out |
|---|---|
| Self-learning ML | Model improves automatically — no retraining button needed after go-live |
| SMS Bot | Inclusive for non-smartphone users — unique in the healthcare app space |
| E2EE Chat | End-to-end encrypted doctor-patient communication — rare in clinic apps |
| Audit Chain | Tamper-evident hash-chained audit log — enterprise/compliance grade |
| Multi-surface | Six distinct, role-optimized app surfaces from a single Firebase project |
| Real-time event vocabulary | Named socket events map directly to clinical workflows, not generic updates |
