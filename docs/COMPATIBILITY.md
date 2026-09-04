# Compatibility Policy

Orynquix does not promise universal desktop application support. Each catalog entry must have exactly one primary badge backed by a tested install and launch procedure on a declared device profile.

| Badge | Meaning |
| --- | --- |
| Native | ARM64 Linux build runs locally in the supported guest path. |
| Integrated Android | The action deliberately hands off to an Android application. |
| Web/PWA | The supported experience is the official browser application. |
| Translated — Experimental | Architecture or Windows translation is opt-in and proven only for the named version/device. |
| Remote | The application runs on another computer and Orynquix provides secure access. |
| Unsupported | No safe, usable and verified path exists for this edition. |

Stage 1 verifies the desktop foundation only. It contains no application catalog and makes no claim about Windows x86_64 apps, Docker daemons, kernel modules, KVM, privileged containers, macOS/iOS binaries, DRM, anti-cheat or GPU-heavy professional software.

An entry may display **Install** only when its manifest is schema-valid, its source is trusted, its procedure is implemented, and its launch check is supported. Documentation or an untested idea must never be presented as an install action.

