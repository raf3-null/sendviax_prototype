# Sendviax AI Development Rules

## Scope control

- Read `/PROJECT_SCOPE.md` before planning or implementing product work.
- Do not implement a feature outside the approved project scope without explicit human approval.
- Treat a listed target or future feature as planned, not implemented, until code and relevant tests exist.

1. Read `/protocol` before implementing network, transfer, crypto, device, or session features.
2. `/protocol` is the source of truth for cross-platform behavior.
3. Do not modify protocol specifications just to make an implementation easier.
4. If a protocol change appears necessary:
   - stop implementation,
   - explain the problem,
   - propose the protocol change,
   - wait for human approval before changing it.
5. Never change cryptographic primitives without explicit human approval.
6. Never implement custom cryptographic algorithms.
7. Use native/well-reviewed cryptographic libraries.
8. Relay must never decrypt user content.
9. Private keys must never leave their device.
10. Temporary Session Secret must never be sent to the backend.
11. Never log sensitive plaintext or secrets.
12. All platform implementations must be interoperable.
13. Shared crypto behavior must have test vectors in `/test-vectors`.
14. New API endpoints must be documented.
15. Database schema changes require migrations.
16. New dependencies must have a clear justification.
17. Run relevant tests before considering a task complete.
18. Do not modify unrelated platforms/files unless required.
19. Prefer small, reviewable commits.
20. Do not mark incomplete implementations as production-ready.
21. Clearly document OS-specific limitations.
22. iOS/iPadOS must respect Apple clipboard/background restrictions.
23. Linux must not assume unrestricted clipboard access under Wayland.
24. HarmonyOS features must not be claimed as supported until validated against the actual API/device requirements.
25. Never commit:
   - `.env`
   - API keys
   - passwords
   - access tokens
   - refresh tokens
   - database credentials
   - private keys
   - certificates containing private keys
   - Session Secrets
