# Web phases 1–5: approved extension (2026-09-23)

## macOS extension approved 2026-09-24

The user approved the macOS roadmap. The desktop app may use the same web1 pairing/state/receipt endpoints with platform `macOS`, retaining explicit legacy mode for older clients. Crypto/envelope and server quotas remain unchanged. Room credentials, drafts, replay IDs and received content remain in process RAM, bounded by 20 records / 20 MiB and envelope/room expiry using continuous time including sleep. Closing the window may leave the app receiving in the menu bar; exiting ends local access and attempts server revocation, with server TTL still authoritative if the request cannot finish.

Clipboard reads are user-triggered only. Copy-selection shortcut must observe a fresh pasteboard change and unchanged foreground app; otherwise it refuses to stage stale clipboard content. The user additionally approved an optional immediate-send shortcut on 2026-09-24. It defaults off and stores only the preference in UserDefaults. When enabled, fresh content with a clear local scanner result may upload immediately to the confirmed room; sensitive, unsupported or invalid-text scan results still require confirmation. Pending/busy/changed-room states must not auto-send. Wire crypto and endpoints are unchanged. Paste shortcut acts only on explicit invocation and does not press Enter/send in the destination app. Text/image/file paste is conditional on the destination and OS permissions.

Explicit Copy of a file may create a private temporary file so macOS can expose a real file URL to the destination, instead of leaking a source-machine path. Remove app-owned temporary exports when their deadline expires or the room closes; app termination/crash may defer physical cleanup and does not recall destination copies. Explicit Save is a user-owned persistent export. No HTML/SVG inline rendering, persistent secret, account/group implementation, new backend endpoint or primitive is introduced.

## Android extension approved 2026-09-23

The user approved Android interoperability with this pairing flow. Android 0.3 may create, claim, confirm, rename, poll and close web1 rooms using the same endpoints, envelopes and platform `Android`. Legacy mode remains explicit for older clients. Claim retry identifiers and invitations stay in process RAM. The foreground service polls state before transfers and never receives or sends while unconfirmed. Inbox content expires at the earliest of envelope expiry, room expiry and 300 seconds after receipt, using elapsed time including sleep. Clearing content retains replay IDs. QR encoding is local. No cryptographic primitive, envelope or backend endpoint changes.

Account/group approval expands the roadmap but does not make web1 a multi-party protocol. A group must not reuse this shared-room-secret mechanism. Account configuration and group key authentication remain separate work.

The user approved the proposed web roadmap and explicitly requested implementation of web first. This document specifies the web pairing, device presence and delivery status needed by phases 1–5. It extends temporary sessions only; no trusted devices/accounts, P2P, persistent storage, multi-file, resume or new cryptographic primitives. Existing native test-v0 clients and endpoints remain compatible in legacy rooms.

## Wire and storage

Payloads/envelopes remain exactly test-v0 (AES-256-GCM/HKDF, AAD, limits and existing vectors). Secrets exist only in client RAM and invitation URL fragments. QR is generated locally, never through an external QR service. Backend stores capability/ticket, temporary device labels and delivery metadata, never payload plaintext/secret/hash. All state is memory-only, one worker; no database migration. Rooms last 900 seconds, invitations/confirmation 300 seconds bounded by room expiry. Existing body, room, replay and rate quotas apply. Device names/platform are explicitly unverified client metadata, not identity proof.

## Pairing

New `POST /api/web/sessions` body `{session_id,name,platform}` returns owner_token, invite_token, expires_at, invite_expires_at. Peer capability is not issued until claim. Invitation `/try#v=web1&s=<id>&k=<secret>&t=<invite_token>` is parsed strictly and fragment removed immediately. The client must keep it in RAM only. Legacy `/try#s=...&k=...&t=<peer_token>` still works in legacy mode.

`POST /api/web/join` body `{session_id,invite_token,claim_id,name,platform}` atomically consumes an unexpired invitation and returns peer_token, expires_at, confirmation_code. claim_id is random 128-bit lowercase hex in RAM; repeating the identical ticket/claim_id retries a lost response while awaiting confirmation, other claims return 409. Both role capabilities are independent random 256-bit values. Codes are random six decimal digits, displayed only to the peer; owner asks the intended peer for the code and submits `POST /api/web/confirm {code}` with owner Bearer capability. Maximum five incorrect attempts closes the room; confirmation timeout also closes the room. No transfers permitted until confirmed. Reject means close room and create a fresh room/secret, not reuse rejected credentials. The code confirms a claimant to the owner, not authenticated key exchange, MFA or protection against a compromised relay/client bundle.

## Metadata and lifecycle

`GET /api/web/state` with role Bearer capability updates that role heartbeat and returns session_id, role, expires_at, pairing (`waiting`, `pending`, `confirmed`), invite_expires_at, devices (role/name/platform/last_seen/online), own outbound receipts. A device is `online` only if its last request to this endpoint was within 12 seconds; UI labels this recent contact rather than proof of continuous availability. Pending peer gets no owner name until confirmation. Owner never gets confirmation_code from this endpoint. Client clears code/invite after confirmed.

`PATCH /api/web/device {name}` renames only the authenticated role. Name: 1–40 trimmed Unicode characters, no control characters; platform is an allowlisted client-declared platform. `DELETE /api/web/session` lets either participant close the complete two-party room, erasing both capabilities, ticket, metadata and ciphertext. Existing owner-only `DELETE /api/test/session` remains valid. Refresh loses client credentials; it is not background persistence or accountless trusted pairing.

Existing `/api/test/transfers` POST/GET/ACK enforce confirmation for web rooms. Upload records sender-only status `available`; recipient ACK removes ciphertext and records `completed` plus timestamp. Repeated authenticated recipient ACK returns completed for web rooms only. Item expiry removes ciphertext and changes receipt to `expired`. State receipts bounded by 256 room IDs; no names/content/digests stored there. `completed` means recipient client reported successful authenticated decryption and retained the item, not user opened/pasted or independently verified by server. A capability holder can lie about ACK. Legacy rooms retain existing 404 repeated-ACK semantics.

## Client content

Retain at most 20 items/20 MiB decoded payload bytes in RAM, with content expiry bounded by envelope/room expiry. Keep replay IDs separately until room ends, including after clearing inbox or evicting content. After content expiry only non-sensitive status counters/IDs may remain for room duration; history is session-only, no Pin/persistent history. Close/revoke/expiry clears content, previews and drafts. Check deadlines before every copy/open/download, and on focus/visibility changes. No background clipboard monitoring.

Text/code/URL, images, PDF/audio and any single file remain existing payload types; PDF/audio are files, not active embedded documents. Show raster previews only after native decoder validation/dimension limits (8192 per side, 32M pixels), never render HTML/SVG. Download other files as octet-stream. Image clipboard uses validated raster converted to PNG on explicit user action if supported; failure offers download. Sensitive-data scanner runs locally before encryption, makes no safety guarantee and reports unsupported binary scanning honestly. No new crypto vectors required because wire crypto unchanged; pairing/lifecycle have integration tests.

## HTTP errors and deployment

All endpoints use no-store responses; credentials go in Authorization or POST body, never query. 400 invalid request/code; 401 unknown/expired/revoked capability or invalid invitation; 403 wrong role or unconfirmed pair; 409 consumed invitation; 429 rate limit; 503 capacity. New create shares legacy global create quota. Join has global bounded attempts; confirmation owner-authenticated with five-try room limit. This remains a bounded internet test, not a production abuse/security certification. Use HTTPS, keep access logs free of request bodies/credentials. Pending rooms are inaccessible to old mobile versions; use explicitly labeled legacy mode for them until their later upgrade.

### macOS image auto-send approval — 2026-09-24
The user explicitly approved immediate image sending without review, an image-only preference, and a separate action to send the existing clipboard. Image scanning remains unsupported; sensitive text and unsupported non-image files retain review. Option+C still requires a fresh copy; the explicit clipboard action does not synthesize Copy. Optional resizing is user-triggered. Envelope, crypto, size limit and relay APIs remain unchanged.
