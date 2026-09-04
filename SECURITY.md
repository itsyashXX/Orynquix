# Security Policy

## Supported versions

Orynquix is pre-alpha. Only the latest commit on the active Stage 1 branch receives security fixes. No release is currently recommended for sensitive or production workloads.

## Report a vulnerability

Do not open a public issue containing credentials, private device data or an immediately exploitable vulnerability. Use GitHub's private security-advisory reporting for this repository when available. Include the affected commit, diagnostic identifier, reproduction steps, impact and a minimal redacted support bundle.

## Security invariants

- Orynquix runs without root and never requests root.
- `proot` is not treated as a sandbox.
- Stage 1 starts no network service.
- Future network services must bind to loopback by default.
- Commands are argument arrays, not interpolated shell strings.
- Downloaded artifacts require trusted HTTPS and verification before they become an install path.
- Process signals require PID, start-time and command-line identity matches.
- User projects are separate from removable system state.
- Telemetry is absent in Stage 1.

