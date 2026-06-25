# MediQue Security Hardening Runbook

This project now includes technical hardening for PHI-like healthcare data handling.

## Implemented in code

- Stronger Firestore least-privilege rules (`firestore.rules`)
- Queue write field restrictions and owner checks
- Private security namespace (`artifacts/{appId}/private/**`) admin-only
- `notifyPatient` endpoint now requires authenticated admin Firebase ID token
- CORS allowlist support through `ALLOWED_ORIGINS` env var
- OTP flow hardened:
  - hashed OTP storage (SHA-256 + pepper)
  - resend cooldown
  - attempt limits and lockout
  - OTP docs moved to private namespace
- SMTP secrets removed from source and moved to environment variables
- Security audit event logging in Firestore private audit collection

## Required environment variables (Functions)

Set these for local/dev/prod Functions runtime:

- `APP_ID` (e.g. `aishwaryam-acu`)
- `ADMIN_EMAIL` (admin account email)
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM` (optional)
- `PASSWORD_RESET_CONTINUE_URL` (optional, defaults to hosted index page)
- `PASSWORD_RESET_COOLDOWN_SECONDS` (optional, default `60`)
- `OTP_PEPPER`
- `OTP_MAX_ATTEMPTS` (optional, default `5`)
- `OTP_COOLDOWN_SECONDS` (optional, default `45`)
- `NEAR_RT_RETRAIN_MIN_INTERVAL_MINUTES` (optional, default `20`)
- `NEAR_RT_RETRAIN_SAMPLE_DELTA` (optional, default `15`)
- `NEAR_RT_RETRAIN_LOCK_MINUTES` (optional, default `8`)
- `PHONE_HOOK_SECRET` (required if phone hook is exposed)
- `ALLOWED_ORIGINS` (comma-separated list)
- `RETENTION_QUEUE_DAYS` (default `365`)
- `RETENTION_AUDIT_DAYS` (default `2190`)
- `RETENTION_OTP_DAYS` (default `30`)
- `RETENTION_ML_SAMPLE_DAYS` (default `365`)

Example value for `ALLOWED_ORIGINS`:

`https://aishwaryam-acu.web.app,https://aishwaryam-acu.firebaseapp.com,http://localhost:5000,http://127.0.0.1:5000,http://localhost:8080,http://127.0.0.1:8080`

## Access model

- Admin is recognized by:
  - custom claim: `role == "admin"` OR
  - fallback email match (`ADMIN_EMAIL`)
- Use callable function `setUserRole` to assign role claims securely.
- Use callable function `runSecurityMaintenanceNow` to manually execute retention + archive pipeline.

## Operational controls still required for HIPAA readiness

- Signed BAA with all cloud/vendors handling PHI
- Key rotation process for SMTP/pepper/secrets
- Incident response + breach notification playbook
- Workforce training and access review process
- Backups + restore test evidence
- Audit log retention policy
- Device/session management policy

## Verification checklist

1. Patient user cannot read or write another patient's profile/visits.
2. Patient user cannot edit queue PII after creation.
3. `notifyPatient` fails without bearer token and succeeds for admin.
4. OTP documents are in `artifacts/{appId}/private/otps/*` and store only hash.
5. Firestore private paths are inaccessible to non-admin users.
6. Audit logs are being written under `artifacts/{appId}/private/audit_logs`.
7. Archive chain docs are created under `artifacts/{appId}/private/audit_archive` with `prevHash` + `payloadHash`.
8. Expired OTP docs are auto-deleted and old queue docs are redacted by scheduled maintenance.

## New automated controls

- Scheduled maintenance (`scheduledSecurityMaintenance`) runs daily:
  - Exports audit logs into tamper-evident hash chain archive
  - Redacts old queue PHI
  - Deletes expired OTP records
  - Deletes old ML samples
  - Purges already-archived raw audit logs after retention period
- Near real-time ML adaptation:
  - Fresh queue completion samples increment a pending counter
  - Model retrains automatically when sample delta + min time interval thresholds are met
  - Locking prevents concurrent duplicate retraining bursts

- Manual maintenance callable:
  - `runSecurityMaintenanceNow` (admin only)
