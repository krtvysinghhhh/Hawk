# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## Reporting a Vulnerability

We take the security and privacy of HAWK users seriously.

If you discover a security vulnerability or sensitive information exposure:

1. **Do NOT open a public GitHub issue.**
2. Send a confidential report to `security@hawk-music.app` (or contact repository maintainers via GitHub Private Vulnerability Reporting).
3. Include:
   - Type of issue (e.g., credential leak, memory corruption, insecure transport).
   - Detailed step-by-step reproduction instructions.
   - Proof-of-concept code or network payloads if applicable.
   - Any proposed mitigations or patches.

---

## Security Principles in HAWK

- **Local-First Privacy:** HAWK collects zero telemetry and transmits no user identifiers to external analytical services.
- **Hardware Enclave:** All persistent secrets, tokens, and credentials are encrypted using Apple Keychain services.
- **Strict Transport:** App Transport Security (ATS) is enforced; all streaming and metadata connections utilize TLS 1.3/1.2.
