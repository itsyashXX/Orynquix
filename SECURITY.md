# Security policy

Do not open a public issue containing passwords, tokens, private logs, IP addresses, or personal files.

For a suspected vulnerability, use GitHub's private vulnerability reporting for `itsyashxx/orynquix` when available. Include the Orynquix version, Android/Termux versions, architecture, impact, reproduction steps, and a redacted diagnostic excerpt.

The supported security-update target begins with the first public alpha release. Until an alpha is tagged and device-validated, the repository is development software and should not be exposed to untrusted networks.

Orynquix does not create a security boundary equivalent to a virtual machine. It runs without Android root inside Termux/PRoot, and LAN VNC will remain disabled by default.
