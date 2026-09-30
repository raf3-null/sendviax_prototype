# Cryptographic Specification

## Status

Initial specification skeleton; not implementation-ready.

## Approved baseline

- Payload encryption: AES-256-GCM
- Trusted-device key agreement: P-256 ECDH
- Key derivation: HKDF-SHA-256
- Hash: SHA-256
- Temporary Session ID: 128-bit random value
- Temporary Session Secret: 256-bit random value

Never invent custom cryptography or silently substitute primitives. Private keys stay on-device. Temporary Session Secrets never reach the backend or browser LocalStorage/SessionStorage. Precise encodings, key lifecycle, nonce rules, HKDF inputs, authenticated data, and failure handling remain to be specified and approved before implementation.

