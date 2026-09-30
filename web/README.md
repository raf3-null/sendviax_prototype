# Temporary Web Next.js/TypeScript sender and receiver

Product scope: [PROJECT_SCOPE.md](../PROJECT_SCOPE.md). This product directory is scaffolding, not a claim that the platform or service is complete.

Existing experimental code: [OS probe](../tools/os-probes/web/). See [test guide](../tools/os-probes/README.md) for limitations. A local probe or emulator run is not a cross-device transfer test.

The current `/try` workspace implements the approved web phases 1–5: local QR/one-time invite, owner confirmation code, temporary device names/presence, encrypted single-item transfer, sender ACK receipts, preview/copy/download, expiry and clear. [Setup and validation](../docs/web-phases-1-5-validation.md), [API contract](../protocol/web-pair-v1.md). The explicitly labeled legacy room mode remains compatible with current mobile apps. `qrcode` encodes invitations locally; secrets never go to an external QR service. UI/runtime data is memory-only; this is not persistent trusted pairing or production hosting.
