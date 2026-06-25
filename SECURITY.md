# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.x     | ✅ Yes     |
| 1.x     | ❌ No      |

## Reporting a Vulnerability

**Please do NOT file a public GitHub issue for security vulnerabilities.**

If you discover a security vulnerability in MediQue, please report it responsibly:

1. **Email:** Send details to the project maintainer privately.
2. **Include:**
   - A clear description of the vulnerability
   - Steps to reproduce or a proof-of-concept
   - Potential impact assessment
   - Any suggested mitigations

You will receive an acknowledgment within **48 hours** and a status update within **7 days**.

## Security Architecture Highlights

MediQue implements the following security controls:

- **Firestore Default-Deny Rules:** All collections default to `allow: false`. Access is granted only by role/ownership.
- **OTP Hardening:** 6-digit OTPs are SHA-256 + pepper hashed at rest. Attempt limits (5) and cooldown (45s) enforced.
- **API Authentication:** All HTTP Cloud Function endpoints require admin Bearer token verification.
- **CORS Enforcement:** Origin allowlist enforced on all HTTP endpoints.
- **Audit Chain:** All sensitive actions logged with hash-chained tamper evidence (`prevHash` linking).
- **PHI Protection:** Patient-identifying fields are redacted in audit logs (hashed references only).
- **Data Retention:** Automated scheduled pipeline purges aged OTP docs, queue PHI, and ML samples.
- **E2EE Chat:** WebRTC signaling with public-key registry for end-to-end encrypted messages.
- **Private Namespace:** OTPs, audit logs, and security archives stored in `private/` — admin-only access.

## Known Limitations (Roadmap)

- Formal HIPAA compliance requires organizational controls beyond code (BAAs, access governance, incident response).
- KMS-managed envelope encryption for highly sensitive fields is planned for a future release.
- SIEM/WORM immutable external audit export is on the roadmap.

## Security Disclosure Timeline

| Stage              | Target Timeline |
|--------------------|-----------------|
| Acknowledgment     | 48 hours        |
| Initial assessment | 5 business days |
| Fix + patch        | 14 business days|
| Public disclosure  | After patch release |
