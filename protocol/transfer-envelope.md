# Transfer Envelope

## Status

Initial specification skeleton; no wire format has been approved.

The transfer envelope will define versioning, authenticated metadata, ciphertext representation, content types, size limits, expiry, and validation rules. It must not contain plaintext user content, private keys, Content Keys, or Temporary Session Secrets.

Do not implement or infer fields until this document and corresponding schemas and test vectors are reviewed.

