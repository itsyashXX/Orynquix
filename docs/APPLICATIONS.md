# Applications and compatibility

The installer never marks an optional application stage complete until the configured browser, editor, and development package set pass post-install checks.

## Installation choices

- **Browser:** Chromium, Firefox, both, or skip. An already compatible Chromium binary is preserved. Because Ubuntu Chromium normally requires Snap, Orynquix otherwise installs Firefox from Mozilla's signed APT repository and records the fallback.
- **Editor:** automatic, VS Code desktop, code-server, both, or skip. Automatic tries Microsoft's signed ARM64/AMD64 repository and installs official code-server when desktop VS Code cannot be installed.
- **Development:** none, recommended, full, or a custom comma-separated group list. Groups include Git/GitHub CLI, Python, Node.js, Java, C/C++, CMake, Clang, Jupyter, database clients, and Neovim.

The compatibility launchers centralize PRoot-only flags:

- `orynquix-code` adds `--no-sandbox --disable-dev-shm-usage` because Electron cannot create its namespace sandbox and Android's shared-memory layout differs from normal Linux.
- `orynquix-firefox` sets `MOZ_DISABLE_CONTENT_SANDBOX=1` because standard PRoot cannot provide the required namespaces.

These switches weaken application process isolation. They do not disable TLS validation, browser web security, certificate checks, or same-origin protections.

## CLI

```bash
orynquix apps
orynquix install PACKAGE...
orynquix remove PACKAGE...
orynquix search QUERY
orynquix code [PATH]
orynquix code-server
orynquix firefox [HTTPS_URL]
orynquix chromium [HTTPS_URL]
orynquix theme dark|light
orynquix ui-scale 1|1.25|1.5|2
```

Package names and search input are validated before being passed to Ubuntu. `orynquix chromium` fails honestly when no compatible binary exists; it never claims the Firefox fallback is Chromium.
