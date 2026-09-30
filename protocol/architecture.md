# Protocol Architecture

## Status

Initial specification skeleton; not implementation-ready.

## Invariants

- Sensitive-data detection occurs locally before encryption or upload.
- The relay handles only ciphertext and protocol metadata and never decrypts user content.
- Relay and Cloudflare R2 storage are temporary; object storage contains ciphertext only.
- Private keys remain on their originating devices.
- Trusted and temporary modes must interoperate according to reviewed shared specifications.

Detailed roles, trust boundaries, state machines, retention rules, and threat model remain to be specified and approved.

