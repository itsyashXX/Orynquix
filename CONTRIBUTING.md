# Contributing

Orynquix accepts focused changes that keep the system real, reliable, repairable, secure, performant, and then beautiful.

Before submitting a change:

1. Keep shared behavior in `lib/`; do not duplicate host/Ubuntu adapters.
2. Add an action and a verifier for every installer stage.
3. Never mark a stage complete before its verifier succeeds.
4. Preserve user homes and configuration by default.
5. Do not add creator-specific device values, credentials, telemetry, or unverified downloads.
6. Update tests and relevant documentation.
7. Run the commands in `docs/DEVELOPMENT.md`.

Installation changes must explain clean-install behavior, rerun behavior, failure diagnosis, repair, data preservation, ARM64 support, and PRoot limitations.
