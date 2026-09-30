# macOS / iOS / iPadOS Swift/SwiftUI

macOS 0.2 now has a native SwiftUI/AppKit app, Menu Bar panel, web1 and legacy relay pairing, device state, receipts, explicit clipboard/file actions and opt-in global shortcuts. Universal Apple Silicon/Intel test packages are built with `sh scripts/build-macos.sh`. See [macOS setup and validation](../docs/macos-0.1-validation.md). This is an ad-hoc signed local test build, not a notarized release. Accounts/groups remain unavailable. The older scaffolding status below describes the earlier mobile milestone.

Product scope: [PROJECT_SCOPE.md](../PROJECT_SCOPE.md). This directory contains experimental implementations, not a claim that the platform or service is complete.

The iOS/iPadOS experimental app now lives in [mobile/Sendviax.xcodeproj](mobile/Sendviax.xcodeproj). SwiftUI app, custom keyboard and Share Extension use the web theme. Native test-v0 scope was approved on 2026-09-21. Simulator build and native/core interoperability checks pass; physical-device signing and UI acceptance are separate. The macOS experiment is documented above.

See [mobile setup and limitations](../docs/mobile-test-th.md). Build with `sh scripts/build-mobile.sh ios` from the repo root. No signed distributable IPA is provided.

iOS 0.2 adds the user-approved automatic shared keyboard inbox: visible-keyboard polling with Full Access, temporary shared Keychain room credentials, text insertion and image copy/manual paste. See [implementation, signing and validation](../docs/ios-auto-keyboard-validation.md). App Groups and Keychain Sharing must be provisioned for the same development team; physical-device behavior remains unverified.

Existing experimental code: [OS probe](../tools/os-probes/apple/). See [test guide](../tools/os-probes/README.md) for limitations. A local probe or emulator run is not a cross-device transfer test.

macOS 0.2 adds optional immediate sending with Option+C; see [shortcut settings and validation](../docs/macos-0.2-shortcut.md).
