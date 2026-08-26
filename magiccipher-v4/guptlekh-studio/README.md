# MagicCipher Studio V4

A full-stack TypeScript cryptography workbench with two modes:

- **Magic Analyzer** — automatic structural detection, classical-cipher search, multilingual scoring, recursive decoding, XOR, Affine, Caesar, Atbash, ROT47, keyboard shifts, and Vigenère speculation/frequency analysis.
- **Transform Lab** — deterministic encrypt/decrypt for Vigenère, Caesar, ROT13, Atbash, Base64, Hex, XOR, and AES-256-GCM.

## V4 changes

- Key/hint removed from the main Magic flow; it now lives under **Advanced analysis** only.
- Cleaner result cards with clear plaintext, confidence, score bar, copy action, and collapsible evidence.
- Alternatives are collapsed by default instead of flooding mobile screens.
- Ranking no longer rewards “readable Unicode” enough to promote random output by itself.
- Multi-step speculative chains receive a penalty.
- Added statistical Vigenère key-length/column-frequency candidates for longer ciphertext.
- Increased search budget to 2,500 transformations.
- Improved blue/cyan UI motion, responsive spacing, hover states, scanline, aurora, and reduced-motion support.

## Run

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Important cryptography note

No ciphertext-only tool can guarantee decryption of arbitrary keyed encryption. For Vigenère or modern encryption, an exact key can be decisive. V4 keeps a known-key field available under Advanced analysis and in Transform Lab without making it part of the default Magic workflow.
