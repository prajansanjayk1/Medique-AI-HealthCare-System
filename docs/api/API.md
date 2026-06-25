# MediQue — API Reference

> **Base URL (Production):** `https://us-central1-medique-b29ee.cloudfunctions.net`
> **Base URL (Emulator):** `http://localhost:5001/medique-b29ee/us-central1`

---

## Authentication

All protected HTTP endpoints require an **Admin Bearer Token** in the `Authorization` header:

```http
Authorization: Bearer <firebase-id-token>
```

Callable functions use the Firebase SDK and authenticate automatically via the current user session.

---

## HTTP Endpoints

### POST `/notifyPatient`

Dispatches a push/SMS notification to a specific patient. Requires admin or staff authentication.

**Headers:**
```http
Content-Type: application/json
Authorization: Bearer <admin-id-token>
```

**Request Body:**
```json
{
  "patientId": "uid_abc123",
  "message": "It's almost your turn! Please proceed to Room 2.",
  "clinicId": "medique-b29ee",
  "notificationType": "turn_alert"
}
```

**Response — 200 OK:**
```json
{
  "success": true,
  "notified": "uid_abc123"
}
```

**Response — 403 Forbidden:**
```json
{
  "error": "Unauthorized"
}
```

---

### POST `/phoneCallHook`

Handles incoming telephony/SMS webhook events. Used by the SMS Bot integration.

**Headers:**
```http
Content-Type: application/json
X-Hook-Secret: <PHONE_HOOK_SECRET>
```

**Request Body:**
```json
{
  "from": "+919876543210",
  "body": "JOIN QUEUE",
  "clinicId": "medique-b29ee"
}
```

**Response — 200 OK:**
```json
{
  "success": true,
  "action": "external_check_in",
  "token": "Q042"
}
```

---

## Callable Functions

Callable functions are invoked using the Firebase SDK:

```javascript
// Web SDK
const fn = firebase.functions().httpsCallable('functionName');
const result = await fn({ ...params });
```

```dart
// Flutter SDK
final fn = FirebaseFunctions.instance.httpsCallable('functionName');
final result = await fn.call({ ...params });
```

---

### `sendOtpEmail`

Issues a 6-digit OTP to the authenticated user's email.

**Auth:** Any authenticated user

**Request:**
```json
{}
```

**Response:**
```json
{
  "success": true,
  "cooldownSeconds": 45
}
```

**Error codes:**
| Code | Description |
|---|---|
| `otp/cooldown` | OTP was recently sent; wait for cooldown |
| `otp/max-attempts` | Account locked due to too many failed attempts |

---

### `verifyOtpAndLogin`

Verifies a submitted OTP and finalizes the user session.

**Auth:** Any authenticated user

**Request:**
```json
{
  "otp": "482913"
}
```

**Response:**
```json
{
  "success": true,
  "verified": true
}
```

**Error codes:**
| Code | Description |
|---|---|
| `otp/invalid` | Incorrect OTP |
| `otp/expired` | OTP has expired |
| `otp/locked` | Account locked due to repeated failures |

---

### `sendPasswordResetLink`

Sends a custom password reset email via SMTP. Can be called unauthenticated.

**Auth:** None required

**Request:**
```json
{
  "email": "patient@example.com"
}
```

**Response:**
```json
{
  "success": true
}
```

---

### `setUserRole`

Assigns a custom role claim to a Firebase Auth user.

**Auth:** Admin only

**Request:**
```json
{
  "uid": "user_uid_here",
  "role": "doctor"
}
```

**Allowed roles:** `admin`, `doctor`, `receptionist`, `staff`, `patient`

**Response:**
```json
{
  "success": true,
  "uid": "user_uid_here",
  "role": "doctor"
}
```

---

### `predictWaitTime`

Returns an AI-predicted wait time estimate with confidence metadata.

**Auth:** Any authenticated user

**Request:**
```json
{
  "queueAhead": 8,
  "urgentAhead": 2,
  "isEmergency": false,
  "hour": 10,
  "dayOfWeek": 1,
  "avgConsultationMinutes": 7
}
```

**Response:**
```json
{
  "estimatedMinutes": 56,
  "confidence": "high",
  "predictionWindow": {
    "low": 48,
    "high": 64
  },
  "modelVersion": "ridge_regression_v2",
  "trainedAt": "2025-06-24T03:00:00Z"
}
```

**Confidence levels:**
| Level | Meaning |
|---|---|
| `high` | MAE < 5 min; show precise ETA |
| `medium` | MAE 5–12 min; show range |
| `low` | MAE > 12 min; show approximate |
| `fallback` | No trained model; conservative baseline used |

---

### `trainQueueModel`

Triggers an immediate ML model retraining cycle. Restricted to admin.

**Auth:** Admin only

**Request:**
```json
{}
```

**Response:**
```json
{
  "success": true,
  "samplesUsed": 342,
  "metrics": {
    "mae": 4.2,
    "rmse": 6.1,
    "mape": 18.5
  },
  "trainedAt": "2025-06-25T10:32:00Z"
}
```

---

### `runSecurityMaintenanceNow`

Manually triggers the data retention and audit archiving pipeline.

**Auth:** Admin only

**Request:**
```json
{}
```

**Response:**
```json
{
  "success": true,
  "redactedQueue": 12,
  "deletedOtps": 5,
  "archivedAuditLogs": 38,
  "deletedMlSamples": 0
}
```

---

## Scheduled Jobs (Automatic)

| Job Name | Cron | Description |
|---|---|---|
| `scheduledQueueModelTraining` | Daily (3 AM UTC) | Retrains ML model on 90-day rolling dataset |
| `scheduledSecurityMaintenance` | Daily (2 AM UTC) | Redacts aged PHI, purges OTPs, archives audit logs |

---

## Firestore Triggers (Automatic)

| Trigger | Collection | Description |
|---|---|---|
| `enrichQueueEntry` | `queue/{id}` onCreate | Enriches new queue doc with context at time of join |
| `captureQueueTrainingSample` | `queue/{id}` onUpdate | Captures completed visits as ML training samples |

---

## Error Response Format

All errors follow a consistent structure:

```json
{
  "error": "Short error description",
  "code": "error/code",
  "details": "Optional additional context"
}
```

Common HTTP status codes:
| Status | Meaning |
|---|---|
| `200` | Success |
| `400` | Bad request / invalid parameters |
| `401` | Missing or invalid authentication |
| `403` | Authenticated but not authorized (role mismatch) |
| `429` | Rate limited (OTP cooldown) |
| `500` | Internal server error |
