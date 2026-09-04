# Contributing

Orynquix values measured compatibility and repairability over feature count.

1. Open an issue for changes that alter the supported distribution, desktop, data boundary, lifecycle or trust model.
2. Create a focused branch from the current default branch.
3. Keep platform commands behind adapters and pass argument arrays.
4. Add tests for success, idempotency, interruption and failure paths.
5. Run `make check`.
6. Document which real Android/Termux/device configuration was tested. Never generalize one device result into universal support.

Do not add arbitrary shell text to future app manifests, default non-loopback listeners, silent telemetry, destructive recovery, force-push instructions or unsupported Install buttons.

